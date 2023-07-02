use Test::More;

use Mojolicious::Lite -signatures;
use Mojo::CouchDB;
use Mojo::IOLoop;
use Mojo::Server::Daemon;
use MIME::Base64;

my $couch = Mojo::CouchDB->new('http://127.0.0.1:5984/database', 'foo', 'bar');

my $auth = 'Basic ' . encode_base64("foo:bar");

put '/database' => sub {
    my $c = shift;
    ok 1, 'Is database created call working?';
    is $c->headers->{authorization}, $auth, 'Is auth header correct?';
    return $c->rendered(201);
};

my $port   = Mojo::IOLoop->generate_port;
my $daemon = Mojo::Server::Daemon->new(app => app, listen => "http://*:$port");

$daemon->run;

ok $couch->create_db, 'Did create succeed?';

done_testing;