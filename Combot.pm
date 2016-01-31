package Combot;

use	strict;
use warnings;

use Net::GitHub::V3;
use DBI;

use Bot::BasicBot;

use base qw( Bot::BasicBot );
use Unicode::MapUTF8;

use JSON;

sub init {
	my ($self) = @_;

	$self->{insultes} = [
		"T'as encore merdé ? Tu fais de la merde là...",
		"Et c'est le défilé des bugs à la con.",
		"Quoi ? T'as pété le site ? ... vache... on file des accès à n'importe qui de nos jours.",
		"Bravo. T'as tout flingué. Continue comme ça, et tu vas te faire claquer par un robot."
	];

	$self->{help} = [
		"!help affiche l'aide",
		"!agenda {add_seance|add|remove|modify|all}commandes relatives à l'agenda",
		"!updatesite met à jour le site du Haum",
		"!todolist affiche la todolist du Haum",
		"!spaceapi state {open|close|toggle}"
	];

	$self->{agenda_messages} = [
		"Si pour 2016 t'as des projets, viens nous voir et nous en parler !",
		"Si tu aimes bricoler, viens t'amuser avec nous !",
		"Tant que tu n'as pas essayé tu peux encore te passer de nous... VIENS !",
		"Curieux de nature ? Tu trouveras ta place dans notre secte ;)",
		"Si hacker est pour toi plus qu'un truc qu'on entend aux infos, passe nous voir !",
		"Envie de plancher avec nous à d'autres expériences insolites ?"
	];
}

sub said {
	my ($self, $msg) = @_;
	my $master = $self->{master};

	if ($msg->{body} =~ /^!updatesite$/) {
		if ($self->{IRCOBJ}->has_channel_voice($msg->{channel}, $msg->{who})) {
			$self->say(
				who => $msg->{who},
				channel => $msg->{channel},
				body =>  Encode::decode_utf8("Mise à jour du site en cours...")
			);

			my $back = `cd /var/www/haum.org/website-content && git pull && cd /var/www/haum.org/website && source .venv_pelican/bin/activate && rm -r cache/ && make publish && deactivate && echo "OK"`;

			my @out = split( /\n/ , $back);
			my $message;
			if (pop @out  eq "OK") {
				`rsync -avc --delete /var/www/haum.org/website/output/ /var/www/haum.org/build`;
				$message = "Le site est à jour !";
			} else {
				$message = $self->{insultes}[ rand @{$self->{insultes}} ];
			}

			$self->say(
				who => $msg->{who},
				channel => $msg->{channel},
				body => Encode::decode_utf8($message)
			);
		} else {
		  $self->say(
			who => $msg->{who},
			channel => $msg->{channel},
			body => Encode::decode_utf8("On se connait ?")
		  );
		  return;
		}
	}

	# github todolist
	if ( $msg->{body} =~ /^\!todolist\s?(.+)?$/) {

		my $issues;
		my $gh = Net::GitHub::V3->new;
		my $issues_api = $gh->issue;

		my %default_params = (state => 'open');
		if (defined $1) {
			$default_params{labels} = $1;
			$issues = $issues_api->repos_issues(
				$self->{user},
				$self->{repo},
				\%default_params);
		} else {
			$issues = $issues_api->repos_issues(
				$self->{user},
				$self->{repo},
				\%default_params);
		}

		foreach my $issue (@{$issues}) {
			my @labels;
			foreach my $l (@{$issue->{labels}}) {
				push @labels , $l->{name};
			}
			my $body = $issue->{number}.'# '.$issue->{title}.' ['.join('][', @labels).']';
			$self->say({
				channel => $msg->{channel},
				body => Encode::decode_utf8($body),
			})
		}
	}
	# help
	if ( $msg->{body} =~ /^\!help/) {
		foreach (@{$self->{help}}) {
			$self->say(
				who => $msg->{who},
				channel => $msg->{channel},
				body => Encode::decode_utf8($_)
			);
		}
	}

	# agenda
	if ( $msg->{body} =~ /^\!agenda\s?(add_seance|add|remove|modify|all)?\s?(.+)?$/) {

		# Custom sorting function form custom dates
		sub datesort {
			join('', (split '/', (split ' ',$a->[4])[0])[2,1,0]) cmp join('', (split '/', (split ' ',$b->[4])[0])[2,1,0]);
		}

		my $dbh = DBI->connect("dbi:SQLite:dbname=".$self->{agenda_db}) or 	$self->say(
				who => $msg->{who},
				channel => $msg->{channel},
				body => Encode::decode_utf8("Impossible de se connecter à la db ".$self->{agenda_db})
			);

		if (!defined $1 or $1 eq "all") {
			my $query = 'select rowid,* from agenda where status=1 order by rowid asc';
			$query .= " limit 5" if (!defined $1);
			my $sth = $dbh->prepare($query.";");
			$sth->execute();
			my $events = $sth->fetchall_arrayref;
			my @sorted_events = sort datesort @$events;

			foreach my $e (@sorted_events) {
				$self->say(
					who => $msg->{who},
					channel => $msg->{channel},
					body => Encode::decode_utf8("#".$e->[0].": ".$e->[1]." ; ".$e->[2]." le ".$e->[4]. " ".$e->[5])
				);
			}
		} elsif ($self->{IRCOBJ}->has_channel_voice($msg->{channel}, $msg->{who})){
			my $operation; # kind of database operation
			my $sth;
			if ($1 eq "add_seance") {
				if (defined $2 and $2 =~ /(\d{1,2}\/\d{2}\/\d{4}\s\d{1,2}:\d{2})$/) {
					my $message = $self->{agenda_messages}[ rand @{$self->{agenda_messages}} ];
					$sth = $dbh->prepare("insert into agenda (titre,lieu,description,date,status) values (?,?,?,?,1)");
					$sth->execute("Session bidouille", "Local du Haum", $message, $1);
					$operation = "l'insertion";
				} else {
					$self->say(
						who => $msg->{who},
						channel => $msg->{channel},
						body => Encode::decode_utf8('Pour ajouter un élément, : !agenda add_seance JJ/MM/YYYY (h)h:mm')
					);
				}
			}elsif ($1 eq "add") {
				if (defined $2 and $2 =~ /(\d{1,2}\/\d{2}\/\d{4}\s\d{1,2}:\d{2})\s"([^"]+)"\s"([^"]+)"(.+)$/) {
					$sth = $dbh->prepare("insert into agenda (titre,lieu,description,date,status) values (?,?,?,?,1)");
					$sth->execute($3, $2, $4, $1);
					$operation = "l'insertion";
				} else {
					$self->say(
						who => $msg->{who},
						channel => $msg->{channel},
						body => Encode::decode_utf8('Pour ajouter un élément, : !agenda add JJ/MM/YYYY (h)h:mm "Lieu" "Titre" Description')
					);
				}
			} elsif ($1 eq "modify") {
				if (defined $2 and $2 =~ /(\d+)\s(titre|lieu|date|status)\s(.+)$/) {
					$sth = $dbh->prepare("update agenda set ".$2."=? where rowid=?");
					$sth->execute($3, $1);
					$operation = "la modification";
				} else {
					$self->say(
						who => $msg->{who},
						channel => $msg->{channel},
						body => Encode::decode_utf8("Pour modifier un élément, : !agenda modify id [titre|lieu|date|status] nouvelle valeur")
					);
					undef $operation;
				}
			} elsif ($1 eq "remove") {
				if (defined $2 and $2 =~ /(\d+)\s*$/) {
					$sth = $dbh->prepare("update agenda set status=0 where rowid=?");
					$sth->execute($1);
					$operation = "la suppression";
				} else {
					$self->say(
						who => $msg->{who},
						channel => $msg->{channel},
						body => Encode::decode_utf8("Pour supprimer un élément, : !agenda remove id")
					);
					undef $operation;
				}
			}
			if (defined $operation) {
				if ( $sth->err ) {
					$self->say(
						who => "matael",
						channel => $msg->{channel},
						body => Encode::decode_utf8("Erreur pour ".$operation." en base : ".$sth->errstr)
					);
				} else {
					$self->say(
						who => $msg->{who},
						channel => $msg->{channel},
						body => Encode::decode_utf8("C'est dans la boite !")
					);
				}
			}
			return;
		} else {
		  $self->say(
			who => $msg->{who},
			channel => $msg->{channel},
			body => Encode::decode_utf8("On se connait ?")
		  );
		  return;
		}
	}
	if (($msg->{body} =~ /^!spaceapi\s*(state)\s*(.+)$/)) {
		if ($self->{IRCOBJ}->has_channel_voice($msg->{channel}, $msg->{who})) {
			if ($1 eq 'state') {
				my $state = 'false';
				my $twitter_msg = "";

				if ($2 eq 'open') { # Opening
					$state = 'true';
				} elsif ($2 eq 'close') { # Closing
					$state = 'false';
				} elsif ($2 eq 'toggle') {
					my $json = JSON->new->allow_nonref;
					my $json_object = decode_json `curl -s -S -k https://spaceapi.net/new/space/haum/status/json`;
					my $got_state = $json_object->{'state'}{'open'};
					if ($got_state) {
						$state = 'false';
					} elsif (!$got_state) {
						$state = 'true';
					} else {
						$self->say(
							who => $msg->{who},
							channel => $msg->{channel},
							body => Encode::decode_utf8("L'api ne donne pas le status correctement.")
						);
						return;
					}
				} else {
					$self->say(
						who => $msg->{who},
						channel => $msg->{channel},
						body => Encode::decode_utf8("Usage : !spaceapi state open|close|toggle")
					);
					return;
				}

				# forge the message
				if ($state eq 'false') {
					$twitter_msg = "Fin de session ! Jetez un œil à notre agenda sur haum.org pour connaître les prochaines ou surveillez notre fil twitter.";
				} else {
					$twitter_msg = "INFO : notre espace est tout ouvert, n'hésitez pas à passer si vous le voulez/pouvez ! haum.org";
				}

				my $response = `curl -s -S --data-urlencode sensors='{"state":{"open":$state}}' -k --data key='$self->{spaceapikey}' https://spaceapi.net/new/space/haum/sensor/set 2>&1`;
				if ($response eq '') {
					$self->say(
						who => $msg->{who},
						channel => $msg->{channel},
						body => Encode::decode_utf8("All went well !! ~o~")
					);
					$self->say(
							who => $msg->{who},
							channel => $msg->{channel},
							body => Encode::decode_utf8("\@tweet $twitter_msg")
	                );
				} else {
					$self->say(
						who => $msg->{who},
						channel => $msg->{channel},
						body => Encode::decode_utf8("Une réponse de chez SpaceAPI : $response")
					);
				}
			}
		} else {
			$self->say(
				who => $msg->{who},
				channel => $msg->{channel},
				body => Encode::decode_utf8("On se connait ?")
			);
			return;
		}
	}
}

1;
