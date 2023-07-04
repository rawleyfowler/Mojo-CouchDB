use Test::More;

use Mojolicious::Lite -signatures;
use Mojo::CouchDB;
use Mojo::IOLoop;
use Mojo::IOLoop::Server;
use Mojo::IOLoop::Subprocess;
use Mojo::Server::Daemon;
use MIME::Base64;

my $port  = Mojo::IOLoop::Server->generate_port;
my $couch = Mojo::CouchDB->new("http://127.0.0.1:$port/database", 'foo', 'bar');

chomp(my $auth = 'Basic ' . encode_base64("foo:bar"));

put '/database' => sub {
    my $c = shift;
    ok 1, 'Is database created call working?';
    is $c->headers->{authorization}, $auth, 'Is auth header correct?';
    return $c->rendered(201);
};

my $daemon = Mojo::Server::Daemon->new(app => app, listen => ["http://127.0.0.1:$port"]);

my $sub = Mojo::IOLoop::Subprocess->new;

$sub->run(sub {
    $daemon->run;
});

sleep 1;

ok $couch->create_db, 'Did create succeed?';

done_testing;
