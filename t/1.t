use Test::More tests => 21;

use_ok('Mail::Transfer'); 																	# 0001

my $obj1 = Mail::Transfer->new();

ok(defined $obj1, "Mail::Transfer->new() returned something"); 								# 0002
ok($obj1->isa('Mail::Transfer'), ' and it is the right class'); 							# 0003

ok($obj1->debug() == 0, ' debug()');														# 0004
ok($obj1->timeout() == 60, ' timeout()');													# 0005
ok($obj1->message() eq '', ' message()');													# 0006

my $obj2 = Mail::Transfer->new(PEERADDR		=> 'perl.intertivity.com',
							   PEERPORT		=> 80,
							   TIMEOUT		=> 120);

ok(defined $obj2); 																			# 0007
ok($obj2->isa('Mail::Transfer'));															# 0008

ok($obj2->peer_addr() eq 'perl.intertivity.com', ' peer_addr()');							# 0009
ok($obj2->peer_port() == 80, ' peer_port()');												# 0010
ok($obj2->local_addr() eq '', ' local_addr()');												# 0011
ok($obj2->local_port() == 0, ' local_port()');												# 0012
ok($obj2->timeout() == 120, ' timeout()');													# 0013
ok($obj2->timeout(80) == 80, ' timeout(80)');												# 0014
ok($obj2->debug() == 0, ' debug()');														# 0015
ok($obj2->debug(1) == 1, ' debug(1)');														# 0016

ok($obj2->connected() == 0, ' !connected()');												# 0017
ok($obj2->connect(), ' connect()');															# 0018
ok($obj2->connected(), ' connected()');														# 0019

ok($obj2->disconnect(), ' disconnect()');													# 0020
ok($obj2->connected() == 0, ' !connected()');												# 0021
