package Mail::Transfer;

use 5.008;
use strict;
use warnings;

use IO::Socket;

our $VERSION = '0.01';

sub new
{
	my ($class, %args) = @_;

	my $self = {
		_options => {
			PEERADDR    	=> '',
			PEERPORT		=> 0,
			PEERADDR_SSL	=> '',
			PEERPORT_SSL	=> 0,
			SOCKSADDR		=> '',
			SOCKSPORT		=> 1080,
			SOCKSUSER		=> '',
			SOCKSPASSWORD	=> '',
			LOCALADDR		=> '',
			LOCALPORT		=> 0,
			TIMEOUT			=> 60,
			USINGSSL		=> 0,	# 0 == no, 1 == yes, 2 == try first
			USINGSOCKS		=> 0,	# 0 == no, 1 == yes, 2 == try first
		},
		_debug => 0,
		_socket => undef,
		_message => '',
	};

	bless $self, $class;

	$self->_init(%args);

	return $self;
}

sub connect
{
	my ($self, %args) = @_;

	$self->_init(%args);
	$self->disconnect() if $self->connected();

	$self->_connect();

	return $self->connected();
}

sub connected
{
	my $self = shift;
	return $self->{_socket} ? $self->{_socket}->connected() : 0;
}

sub reconnect
{
	my $self = shift;
	return $self->connected() and $self->connect(@_);
}

sub disconnect
{
	my $self = shift;
	return 0 unless $self->connected();
	$self->{_socket}->close();
	undef $self->{_socket};
	return 1;
}

sub message
{
	my $self = shift;
  	my $msg = shift or return $self->{_message};

  	$self->{_message} = $msg;
  	return $msg;
}

sub debug
{
	my $self = shift;
  	my $debug = shift or return $self->{_debug};

  	$self->{_debug} = $debug;
  	return $debug;
}

sub peer_addr
{
	my ($self, $addr) = @_;
	return $self->_get_or_setandreconnect('PEERADDR', $addr);
}

sub peer_port
{
	my ($self, $port) = @_;
	return $self->_get_or_setandreconnect('PEERPORT', $port);
}

sub peer_addr_ssl
{
	my ($self, $addr) = @_;
	return $self->_get_or_setandreconnect('PEERADDR_SSL', $addr);
}

sub peer_port_ssl
{
	my ($self, $port) = @_;
	return $self->_get_or_setandreconnect('PEERPORT_SSL', $port);
}

sub local_addr
{
	my ($self, $addr) = @_;
	return $self->_get_or_setandreconnect('LOCALADDR', $addr);
}

sub local_port
{
	my ($self, $port) = @_;
	return $self->_get_or_setandreconnect('LOCALPORT', $port);
}

sub sock_addr
{
	my ($self) = @_;
	return $self->connected() ? $self->{_socket}->sockhost() : '';
}

sub sock_port
{
	my ($self) = @_;
	return $self->connected() ? $self->{_socket}->sockport() : 0;
}

sub socks_addr
{
	my ($self, $addr) = @_;
	return $self->_get_or_setandreconnect('SOCKSADDR', $addr);
}

sub socks_port
{
	my ($self, $port) = @_;
	return $self->_get_or_setandreconnect('SOCKSPORT', $port);
}

sub socks_user
{
	my ($self, $user) = @_;
	return $self->_get_or_setandreconnect('SOCKSUSER', $user);
}

sub socks_password
{
	my ($self, $password) = @_;
	return $self->_get_or_setandreconnect('SOCKSPASSWORD', $password);
}

sub timeout
{
	my ($self, $tmo) = @_;
	return $self->_get_or_setandreconnect('TIMEOUT', $tmo);
}

sub _init
{
	my ($self, %args) = @_;

	while(my($key, $val) = each %args)
	{
		$self->{_options}->{uc($key)} = $val;
	}

	1;
}

sub _change_option
{
	my ($self, $key, $value) = @_;

	$key = uc($key);

	if($value and lc($value) ne lc($self->{_options}->{$key}))
	{
		$self->{_options}->{$key} = $value;
		return 1;
	}

	return 0;
}

sub _get_or_setandreconnect
{
	my ($self, $key, $value) = @_;

	if($self->_change_option($key, $value))
	{
		$self->reconnect();
	}

	return $self->{_options}->{uc($key)};
}


sub _connect
{
	my ($self) = @_;

	if($self->{_options}->{USINGSSL} == 0) { return $self->_connect_nossl(); }
	elsif($self->{_options}->{USINGSSL} == 1) { return $self->_connect_ssl(); }
	elsif($self->{_options}->{USINGSSL} == 2) { return $self->_connect_ssl() or $self->_connect_nossl();	}

	$self->message("Option 'UsingSSL' of value [$self->{_options}->{USINGSSL}] is not supported: $!");

	return 0;
}

sub _connect_nossl
{
	require IO::Socket::INET;
	my ($self) = @_;

	my $sock = IO::Socket::INET->new(PeerAddr	=> $self->peer_addr(),
									 PeerPort	=> $self->peer_port(),
									 Proto		=> 'tcp',
									 Type		=> SOCK_STREAM,
									 LocalAddr	=> $self->local_addr(),
									 LocalPort	=> $self->local_port(),
									 Timeout	=> $self->timeout()
									) or $self->message("Could not connect INET socket [$self->peer_addr(), $self->peer_port()]: $!" ) and return 0;
    $self->{_socket} = $sock;

    return 1;
}

sub _connect_socks
{
	require IO::Socket::SOCKS;
	my ($self) = @_;

	my $sock = IO::Socket::SOCKS->new(ProxyAddr		=> $self->socks_addr(),
									  ProxyPort 	=> $self->socks_port(),
									  Username		=> $self->socks_user(),
									  Password		=> $self->socks_password(),
									  ConnectAddr	=> $self->peer_addr(),
									  ConnectPort	=> $self->peer_port(),
									  LocalAddr		=> $self->local_addr(),
									  LocalPort		=> $self->local_port(),
									  Timeout		=> $self->timeout()
									 ) or $self->message("Could not connect SOCKS socket [$self->connect_addr(), $self->connect_port()] via socks [$self->peer_addr(), $self->peer_port()]: $!" ) and return 0;

}

sub _connect_ssl
{
	require IO::Socket::SSL;
	my ($self) = @_;

	my $sock = IO::Socket::SSL->new(PeerAddr	=> $self->peer_addr_ssl() || $self->peer_addr(),
									PeerPort	=> $self->peer_port_ssl() || $self->peer_port(),
									Proto		=> 'tcp',
									Type		=> SOCK_STREAM,
									LocalAddr	=> $self->local_addr(),
									LocalPort	=> $self->local_port(),
									Timeout	=> $self->timeout()
								   ) or $self->message("Could not connect SSL socket [$self->peer_addr(), $self->peer_port()]: $!" ) and return 0;
    $self->{_socket} = $sock;

    return 1;
}

1;

package IO::Socket::SSLSOCKS;

use strict;

1;

__END__

=head1 NAME

Mail::Transfer - Object base class to any mail transfer protocol / Objectorientierte Basisklasse für beliebiges Mailübertragungsprotokoll

=head1 ENGLISH

=head2 Synopsis

	#!/usr/bin/perl

	use strict;	# dont you never ever forget this

	use Mail::Transfer;

	my $mt = Mail::Transfer->new(
		PEERADDR        => 'perl.intertivity.com',
		PEERPORT        => 110,                     # standard POP3 port
		PEERADDR_SSL    => 'perl.intertivity.com',
		PEERPORT_SSL    => 995,                     # standard POP3S port
		SOCKSADDR       => 'socks5.intern',         # some SOCKS5 host
		SOCKSPORT       => 1080,                    # standard SOCKS5 host
		SOCKSUSER       => 'socksuser',
		SOCKSPASSWORD   => 'sockspassword',
		TIMEOUT         => 60,
		USINGSSL        => 2,                       # 0 == no, 1 == yes, 2 == try first
		USINGSOCKS      => 2)                       # 0 == no, 1 == yes, 2 == try first
	or die "Could not create Mail::Transfer object: $!";

	if($mt->connect())
	{
		# do something
		$mt->disconnect();
	}

=head2 Abstract

C<Mail::Transfer> provides an object interface to transfer mails over the wire.
The (hopefully) nice thing about it is that you can choose which kind of socket type (based on C<IO::Socket::INET>,
C<IO::Socket::SSL>, C<IO::Socket::SOCKS>) you want to use. Even SOCKSS is provided using a build in
combination of C<IO::Socket::SSL> and C<IO::Socket::SOCKS> which i will publish as an standalone module
at a later time.

C<Mail::Transfer> defines methods for those operations which are common to all
types of socket and help to distinguish between the socket types used. Operations which are specified to a
mail protocol in a particular domain have methods defined in sub classes of C<Mail::Transfer>.

=head2 Description

=head2 See also

More than just C<Mail::Transfer>: L<Mail::Transfer::POP3|Mail::Transfer::POP3>, L<Mail::Transfer::SMTP|Mail::Transfer::SMTP>

Documentation of the mentioned modules: L<IO::Socket::INET|IO::Socket::INET>, L<IO::Socket::SSL|IO::Socket::SSL>, L<IO::Socket::SOCKS|IO::Socket::SOCKS>

Look at L<http://perl.intertivity.com> for more details.

=head2 Author

Sascha Kiefer, E<lt>sk@intertivity.comE<gt>, L<http://www.intertivity.com>

=head2 Copyright und licence

Copyright 2004 by Sascha Kiefer

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 DEUTSCH

=head2 Synopsis

	#!/usr/bin/perl

	use strict;	# vergiss mal nicht

	use Mail::Transfer;

	my $mt = Mail::Transfer->new(
		PEERADDR        => 'perl.intertivity.com',
		PEERPORT        => 110,                     # standard POP3 port
		PEERADDR_SSL    => 'perl.intertivity.com',
		PEERPORT_SSL    => 995,                     # standard POP3S port
		SOCKSADDR       => 'socks5.intern',         # some SOCKS5 host
		SOCKSPORT       => 1080,                    # standard SOCKS5 host
		SOCKSUSER       => 'socksuser',
		SOCKSPASSWORD   => 'sockspassword',
		TIMEOUT         => 60,
		USINGSSL        => 2,                       # 0 == nein, 1 == ja, 2 == versuch zuerst
		USINGSOCKS      => 2)                       # 0 == nein, 1 == ja, 2 == versuch zuerst
	or die "Konnte Mail::Transfer Objekt nicht erzeugen: $!";

	if($mt->connect())
	{
		# mach was
		$mt->disconnect();
	}

=head2 Abstrakt

C<Mail::Transfer> stellt eine objektorientierte Schnittstelle zum Übertragen von Mails zur Verfügung.
Das (hoffentlich) Tolle daran ist, dass dabei ein beliebiger Socket Typus (basierend auf based on C<IO::Socket::INET>,
C<IO::Socket::SSL>, C<IO::Socket::SOCKS>) verwendet werden kann. Sogar SOCKSS ist durch eine Kombination
von C<IO::Socket::SSL> und C<IO::Socket::SOCKS>, welche ich zu einem späteren Zeitpunkt als eigenständiges
Modul anbieten werde, möglich.

C<Mail::Transfer> definiert solche Methoden, die typischerweise von allen Socket Typen unterstützt werden
und solche, die helfen zwischen den benutzten Socket Typen unterscheiden zu können. Funktionalität, welche
an ein bestimmtes Mail Protokoll gebunden ist, sind in Unterklassen zu C<Mail::Transfer> definiert.

=head2 Beschreibung

=head2 Siehe auch

Mehr zu C<Mail::Transfer>: L<Mail::Transfer::POP3|Mail::Transfer::POP3>, L<Mail::Transfer::SMTP|Mail::Transfer::SMTP>

Dokumentation der erwähnten Module: L<IO::Socket::INET|IO::Socket::INET>, L<IO::Socket::SSL|IO::Socket::SSL>, L<IO::Socket::SOCKS|IO::Socket::SOCKS>
Schau für mehr Informationen auf L<http://perl.intertivity.com> vorbei.

=head2 Author

Sascha Kiefer, E<lt>sk@intertivity.comE<gt>, L<http://www.intertivity.com>

=head2 Kopierrechte und Lizenz

Copyright 2004 by Sascha Kiefer

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
