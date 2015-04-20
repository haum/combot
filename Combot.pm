package Combot;

use	strict;
use warnings;

use Net::GitHub::V3;
use DBI;
use Redis; 			# for authorizations

use Bot::BasicBot;

use base qw( Bot::BasicBot );
use Unicode::MapUTF8;

sub init {
	my ($self) = @_;

	$self->{insultes} = [
		"T'as encore merdé ? Tu fais de la merde là...",
		"Et c'est le défilé des bugs à la con.",
		"Quoi ? T'as pété le site ? ... vache... on file des accès à n'importe qui de nos jours.",
		"Bravo. T'as tout flingué. Continue comme ça, et tu vas te faire claquer par un robot."
	];
}

sub said {
	my ($self, $msg) = @_;

	# redis link
	my $redis_db = $self->{redis_db};
	my $redis_pref = $self->{redis_pref};
	my $master = $self->{master};

	my $rdb = Redis->new();
	$rdb->select($redis_db);

	if ($msg->{body} =~ /^!updatesite$/) {
		if ($rdb->get($redis_pref.$msg->{who})) {
			$self->say(
				who => $msg->{who},
				channel => $msg->{channel},
				body =>  Encode::decode_utf8("Mise à jour du site en cours...")
			);

			my $back = `cd /var/www/haum.org/website && git co upstream && git pull && source .venv_pelican/bin/activate && rm -r cache/ && make publish && deactivate && echo "OK"`;

			my @out = split( /\n/ , $back);
			my $message;
			if (pop @out  eq "OK") {
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

	# agenda
	if ( $msg->{body} =~ /^\!agenda\s?(add|remove|modify|all)?\s?(.+)?$/) {

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
					body => Encode::decode_utf8("#".$e->[0].": ".$e->[1]." ; ".$e->[2]." le ".$e->[4])
				);
			}
		} elsif ($rdb->get($redis_pref.$msg->{who})){
			my $operation; # kind of database operation
			my $sth;
			if ($1 eq "add") {
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
    # add an user to the "known nicks" list
	if (($msg->{who} eq $master) and $msg->{body} =~ /!allow\s*(\w+)/) {
		$rdb->set($redis_pref.$1, 1);
		$self->say(
			who => $master,
			channel => $msg->{channel},
			body => Encode::decode_utf8("Ok ! $1 est maintenant dans la liste des twolls potentiels :3")
		);
	}

	# remove an user from the "known nicks" list
	if (($msg->{who} eq $master) and $msg->{body} =~ /!disallow\s*(\w+)/) {
		$rdb->del($redis_pref.$1) if $rdb->get($redis_pref.$1);
		$self->say(
			who => $master,
			channel => $msg->{channel},
			body => Encode::decode_utf8("Adieu $1, je l'aimais bien")
		);
	}
}

1;

