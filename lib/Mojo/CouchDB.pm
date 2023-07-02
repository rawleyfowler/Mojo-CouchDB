package Mojo::CouchDB;

use Mojo::Base -base;
use Mojo::URL;
use Mojo::UserAgent;
use Mojo::IOLoop;

use Carp qw(croak carp);
use MIME::Base64;

our $VERSION = '0.1';

Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

has 'url';
has 'conn';
has 'auth';

sub new {
    my $self     = shift;
    my $str      = shift;
    my $username = shift;
    my $password = shift;

    return $self unless $str;

    my $url = Mojo::URL->new($str);
    croak qq{Invalid CouchDB URI string "$str"}           unless $url->protocol =~ /^http(?:s)?$/;
    croak qq{No database specified in connection string}  unless exists $url->path->parts->[0];
    carp qq{No username or password provided for CouchDB} unless $username and $password;

    if ($username and $password) {
        $self->{auth} = 'Basic ' . encode_base64("$username:$password");
    }

    $self->{url}  = $url;
    $self->{conn} = Mojo::UserAgent->new;

    return $self;
}

sub save {
    
}

sub ua {

}

1;

=encoding utf8

=head1 NAME

Mojo::CouchDB

=head1 SYNOPSIS

    use Mojo::CouchDB;

    # Create a CouchDB instance
    my $couch = Mojo::CouchDB->new('http://localhost:6984/books');

    # Make a document
    my $book = {
        title => 'Nineteen Eighty Four',
        author => 'George Orwell'
    };

    # Save your document to the database
    my $id = $couch->save($book);

    # If _id is assigned to a hashref, save will update rather than create
    $book->{_id} = $id;
    $book->{title} = 'Dune';
    $book->{author} = 'Frank Herbert'

    # Re-save to update the document
    $id = $couch->save($book);

    # Get the document as a hashref
    my $dune = $couch->get($id);
