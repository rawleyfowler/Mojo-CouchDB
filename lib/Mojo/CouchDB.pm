package Mojo::CouchDB;

use Mojo::Base -base;
use Mojo::URL;
use Mojo::UserAgent;
use Mojo::IOLoop;

use Carp qw(croak carp);
use MIME::Base64;
use Scalar::Util;

use feature 'say';

our $VERSION = '0.1';

has 'url';
has 'auth';
has ua => sub { Mojo::UserAgent->new };

sub new {
    my $self     = shift->SUPER::new;
    my $str      = shift;
    my $username = shift;
    my $password = shift;

    return $self unless $str;

    my $url = Mojo::URL->new($str);
    croak qq{Invalid CouchDB URI string "$str"} unless $url->protocol =~ /^http(?:s)?$/;
    croak qq{No database specified in connection string}
        unless exists $url->path->parts->[0];
    carp qq{No username or password provided for CouchDB} unless $username and $password;

    if ($username and $password) {
        chomp($self->{auth} = 'Basic ' . encode_base64("$username:$password"));
    }

    $self->{url} = $url;

    return $self;
}

sub create_db {
    my $status = shift->_call('', 'put')->result->code;

    # 412 means it already exists.
    return 1 if $status == 201 || $status == 412;

    # 5xx responses
    return undef;
}

sub save {
    my $self = shift;
    my $doc  = shift;

    croak qq{Invalid type supplied for document, expected hashref got: } . (reftype $doc)
        unless (reftype($doc)->hash);
    croak qq{Cannot call save without a document} unless (defined $doc);


}

sub save_many {
    my $self = shift;
    my $docs = shift;

    croak qq{Cannot save many without a documents} unless (defined $docs);
    croak qq{Invalid type supplied for documents, expected arrayref of hashref's got: }
        . (reftype $docs)
        unless (reftype($docs)->array);

    return $self->_call('/bulk_docs', 'post', {docs => $docs});
}

sub _call {
    my $self   = shift;
    my $loc    = shift;
    my $method = shift;
    my $body   = shift;

    my $url
        = $loc && $loc ne '' ? $self->url->to_string . "/$loc" : $self->url->to_string;
    my $headers = {
        Authorization => $self->auth,

    };

    if ($body) {
        return $self->ua->$method($url, $headers, 'json', $body);
    }

    return $self->ua->$method($url, $headers);
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
    $book = $couch->save($book);

    # If _id is assigned to a hashref, save will update rather than create
    say $book->{_id}; # Assigned when saving or getting
    $book->{title} = 'Dune';
    $book->{author} = 'Frank Herbert'

    # Re-save to update the document
    $book = $couch->save($book);

    # Get the document as a hashref
    my $dune = $couch->get($id);

    # You can also save many

=cut