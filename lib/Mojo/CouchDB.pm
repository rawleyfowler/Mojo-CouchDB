package Mojo::CouchDB;

use Mojo::Base -base;
use Mojo::URL;
use Mojo::UserAgent;
use Mojo::IOLoop;

use Carp qw(croak carp);
use MIME::Base64;
use Scalar::Util qw(reftype);

use feature 'say';

our $VERSION = '0.1';

has 'url';
has 'auth';
has ua => sub { Mojo::UserAgent->new };

sub create_db {
    my $status = shift->_call('', 'put')->result->code;

    # 412 means it already exists.
    return 1 if $status == 201 || $status == 412;

    # 5xx responses
    return undef;
}


sub new {
    my $self     = shift->SUPER::new;
    my $str      = shift;
    my $username = shift;
    my $password = shift;

    return $self unless $str;

    chop $str if substr($str, -1) eq '/';

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

sub save {
    my $self = shift;
    my $doc  = shift;
    return $self->_save($doc)->_call('', 'post', $doc)->result->json;
}

sub save_p {
    my $self = shift;
    my $doc  = shift;
    return $self->_save($doc)->_call('', 'post_p', $doc)
        ->then(sub { return shift->res->json });
}

sub save_many {
    my $self = shift;
    my $docs = shift;
    return $self->_save_many($docs)->_call('/bulk_docs', 'post', {docs => $docs})
        ->result->json;
}

sub save_many_p {
    my $self = shift;
    my $docs = shift;

    return $self->_save_many($docs)->_call('/bulk_docs', 'post_p', {docs => $docs})
        ->then(sub { return shift->res->json });
}

sub find {
    my $self = shift;
    my $sc   = shift;
    return $self->_find($sc)->_call('_find', 'post', $sc)->result->json;
}

sub find_p {
    my $self = shift;
    my $sc   = shift;
    return $self->_find($sc)->_call('_find', 'post_p', $sc)
        ->then(sub { return shift->res->json });
}

sub _call {
    my $self   = shift;
    my $loc    = shift;
    my $method = shift;
    my $body   = shift;

    my $url = $loc && $loc ne '' ? $self->url->to_string . "$loc" : $self->url->to_string;

    print $url . "\n" if $ENV{MOJO_COUCHDB_DEBUG};

    my $headers = {Authorization => $self->auth};

    if ($body) {
        return $self->ua->$method($url, $headers, 'json', $body);
    }

    return $self->ua->$method($url, $headers);
}

sub _find {
    my $self = shift;
    my $sc   = shift;

    croak qq{Invalid type supplied for search criteria, expected hashref get: }
        . (reftype $sc)
        unless reftype($sc) eq 'HASH';

    return $self;
}

sub _save {
    my $self = shift;
    my $doc  = shift;

    croak qq{Invalid type supplied for document, expected hashref got: } . (reftype $doc)
        unless reftype($doc) eq 'HASH';
    croak qq{Cannot call save without a document} unless (defined $doc);

    return $self;
}

sub _save_many {
    my $self = shift;
    my $docs = shift;

    croak qq{Cannot save many without a documents} unless (defined $docs);
    croak qq{Invalid type supplied for documents, expected arrayref of hashref's got: }
        . (reftype $docs)
        unless (reftype($docs) eq 'ARRAY');

    return $self;
}

1;

=encoding utf8

=head1 NAME

Mojo::CouchDB

=head1 SYNOPSIS

      use Mojo::CouchDB;

      # Create a CouchDB instance
      my $couch = Mojo::CouchDB->new('http://localhost:6984/books', 'username', 'password');

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
      my $dune = $couch->find({ _id => $book->{_id} });

      # You can also save many documents at a time
      my $books = $couch->save_many([{title => 'book', author => 'John'}, { title => 'foo', author => 'bar' }])->{docs};
    
=head2 create_db

      $couch->create_db

    Create the database, returns C<1> if succeeds or if it already exsits, else returns C<undef>.

=cut
