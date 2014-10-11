use Combot;

my $bot = Combot->new(
	server => "irc.freenode.org",
	port => 7000,
	ssl => 1,
	channels => ['#haum'],
	nick => 'Com`bot',
	redis_db => 3,
	redis_pref => "combot:",
	master => "matael",
	agenda_db => "/home/haum/website/agenda.sqlite"
)->run();

