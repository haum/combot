use Combot;

my $bot = Combot->new(
	server => "irc.freenode.org",
	port => 7000,
	ssl => 1,
	channels => ['#testhaum'],
	nick => 'Com`bot',
	redis_db => 3,
	redis_pref => "combot:",
	master => "matael",
	agenda_db => "/home/matael/mergedbot/agenda_test.sqlite"
)->run();

