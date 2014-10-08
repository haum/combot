#! /usr/bin/env perl -w
#
# combot.pl
#
# Copyright © 2014 Mathieu Gaborit (matael) <mathieu@matael.org>
#
#
# Distributed under WTFPL terms
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
# Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>
#
# Everyone is permitted to copy and distribute verbatim or modified
# copies of this license document, and changing it is allowed as long
# as the name is changed.
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#


use Combot;

my $bot = GitHookBot->new(
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

