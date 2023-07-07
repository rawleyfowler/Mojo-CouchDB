package Mojo::CouchDB;

use Mojo::Base -base;
use Mojo::URL;
use Mojo::UserAgent;
use Mojo::IOLoop;
use Mojo::JSON qw(encode_json);

use Carp qw(croak carp);
use URI;
use MIME::Base64;
use Scalar::Util qw(reftype);
use Storable     qw(dclone);

our $VERSION = '0.3.1';

has 'url';
has 'auth';
has ua => sub { Mojo::UserAgent->new };

sub all_docs {
    my $self  = shift;
    my $query = $self->_to_query(shift);
    return $self->_call('_all_docs' . $query, 'get')->result->json;
}

sub all_docs_p {
    my $self  = shift;
    my $query = $self->_to_query(shift);

    return $self->_call_p('_all_docs' . $query, 'get_p')
        ->then(sub { return shift->res->json });
}

sub create_db {
    return shift->_call('', 'put');
}

sub find {
    my $self = shift;
    my $sc   = shift;
    return $self->_find($sc)->_call('_find', 'post', $sc);
}

sub find_p {
    my $self = shift;
    my $sc   = shift;
    return $self->_find($sc)->_call_p('_find', 'post_p', $sc)
        ->then(sub { return shift->res->json });
}

sub get {
    my $self = shift;
    my $id   = shift;

    $id = $$id while (reftype($id));
    return $self->_get($id)->_call("/$id", 'get');
}

sub get_p {
    my $self = shift;
    my $id   = shift;

    $id = $$id while (reftype($id));
    return $self->_get($id)->_call_p("/$id", 'get');
}

sub index {
    my $self = shift;
    my $idx  = shift;

    return $self->_index($idx)->_call('_index', 'post', $idx);
}

sub index_p {
    my $self = shift;
    my $idx  = shift;

    return $self->_index($idx)->_call_p('_index', 'post_p', $idx);
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
    my $res  = $self->_save($doc)->_call('', 'post', $doc);

    my $dc = dclone $doc;
    $dc->{_id}  = $res->{_id};
    $dc->{_rev} = $res->{_rev};

    return $dc;
}

sub save_p {
    my $self = shift;
    my $doc  = shift;
    return $self->_save($doc)->_call_p('', 'post_p', $doc)->then(sub {
        my $res = shift;

        my $dc = dclone $doc;
        $dc->{_id}  = $res->{_id};
        $dc->{_rev} = $res->{_rev};

        return $doc;
    });
}

sub save_many {
    my $self = shift;
    my $docs = shift;
    return $self->_save_many($docs)->_call('/bulk_docs', 'post', {docs => $docs});
}

sub save_many_p {
    my $self = shift;
    my $docs = shift;

    return $self->_save_many($docs)->_call_p('/bulk_docs', 'post_p', {docs => $docs});
}

sub _call {
    my $self   = shift;
    my $loc    = shift;
    my $method = shift;
    my $body   = shift;

    my $url = $loc && $loc ne '' ? $self->url->to_string . "$loc" : $self->url->to_string;

    my $headers = {Authorization => $self->auth};

    my $r
        = ($body
        ? $self->ua->$method($url, $headers, 'json', $body)
        : $self->ua->$method($url, $headers))->result;

    croak 'CouchDB encountered an error: ' . $r->json->{error}
        if $r->json and exists($r->json->{error});
    croak 'CouchDB encountered an error: ' . $r->code . ' ' . encode_json($r->json)
        unless $r->is_success;

    return $r->json || {};
}

sub _call_p {
    my $self   = shift;
    my $loc    = shift;
    my $method = shift;
    my $body   = shift;

    my $url = $loc && $loc ne '' ? $self->url->to_string . "$loc" : $self->url->to_string;

    my $headers = {Authorization => $self->auth};

    if ($body) {
        return $self->ua->$method($url, $headers, 'json', $body)->then(sub {
            my $r = shift;

            croak 'CouchDB encountered an error: ' . $r->res->json->{error}
                if (exists $r->res->json->{error});

            return $r->res->json;
        });
    }

    return $self->ua->$method($url, $headers)->then(sub {
        my $r = shift;

        croak 'CouchDB encountered an error: ' . $r->res->json->{error}
            if (exists $r->res->json->{error});
        croak 'CouchDB encountered an error: '
            . $r->res->code . ' '
            . encode_json($r->res->json)
            if (!$r->is_success);

        return $r->res->json;
    });
}

sub _find {
    my $self = shift;
    my $sc   = shift;

    croak qq{Invalid type supplied for search criteria, expected hashref got: undef }
        unless $sc;
    croak qq{Invalid type supplied for search criteria, expected hashref got: scalar }
        unless reftype $sc;
    croak qq{Invalid type supplied for search criteria, expected hashref got: }
        . reftype $sc
        unless reftype($sc) eq 'HASH';

    return $self;
}

sub _get {
    my $self = shift;
    my $id   = shift;

    croak qq{Invalid type supplied for id, expected scalar got: undef} unless $id;

    return $self;
}

sub _index {
    my $self = shift;
    my $idx  = shift;

    croak qq{Invalid type supplied for index, expected hashref got: undef } unless $idx;
    croak qq{Invalid type supplied for index, expected hashref got: scalar }
        unless reftype $idx;
    croak qq{Invalid type supplied for index, expected hashref got: } . reftype $idx
        unless reftype($idx) eq 'HASH';

    return $self;
}

sub _save {
    my $self = shift;
    my $doc  = shift;

    croak qq{No save argument specified, expected hashref got: undef } unless $doc;
    croak qq{Invalid type supplied for document, expected hashref got: scalar }
        unless reftype $doc;
    croak qq{Invalid type supplied for document, expected hashref got: } . (reftype $doc)
        unless reftype($doc) eq 'HASH';
    croak qq{Cannot call save without a document} unless (defined $doc);

    return $self;
}

sub _save_many {
    my $self = shift;
    my $docs = shift;

    croak qq{Cannot save many without a documents} unless defined $docs;
    croak
        qq{Invalid type supplied for documents, expected arrayref of hashref's got: scalar }
        unless reftype $docs;
    croak qq{Invalid type supplied for documents, expected arrayref of hashref's got: }
        . (reftype $docs)
        unless (reftype($docs) eq 'ARRAY');

    return $self;
}

sub _to_query {
    my $self  = shift;
    my $query = shift;

    croak qq{Invalid type supplied for query, expected hashref got undef} unless $query;
    croak qq{Invalid type supplied for query, expected hashref got scalar}
        unless reftype $query;
    croak qq{Invalid type supplied for query, expected hashref got: } . reftype($query)
        unless $query && reftype($query) eq 'HASH';

    my $t_uri = URI->new('', 'http');
    $t_uri->query_form(%$query);

    return $t_uri->query;
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
    my $dune = $couch->get($book->{_id});

    # You can also save many documents at a time
    my $books = $couch->save_many([{title => 'book', author => 'John'}, { title => 'foo', author => 'bar' }])->{docs};

=head2 all_docs

    $couch->all_docs({ limit => 10, skip => 5});

Retrieves a list of all of the documents in the database. This is packaged as a hashref with
C<offset>: the offset of the query, C<rows>: the documents in the page, and C<total_rows>: the number of rows returned in the dataset.

Optionally, can take a hashref of query parameters that correspond with the CouchDB L<view query specification|https://docs.couchdb.org/en/stable/api/ddoc/views.html#db-design-design-doc-view-view-name>.

=head2 all_docs_p

    $couch->all_docs_p({ limit => 10, skip => 5 });

See L<\"all_docs">, except returns the result in a L<Mojo::Promise>.
    
=head2 create_db

    $couch->create_db

Create the database, returns C<1> if succeeds or if it already exsits, else returns C<undef>.

=head2 find

    $couch->find($search_criteria);

Searches for documents based on the search criteria specified. The search criteria hashref provided for searching must follow the CouchDB L<_find specification|https://docs.couchdb.org/en/stable/api/database/find.html#selector-syntax>.

Returns a hashref with two fields: C<docs> and C<execution_stats>. C<docs> contains an arrayref of found documents, while
C<execution_stats> contains a hashref of various statistics about the query you ran to find the documents.

=head2 find_p

    $couch->find_p($search_criteria);

See L<\"find">, except returns the result asynchronously in a L<Mojo::Promise>.

=head2 get

    $couch->get($id);

Finds a document by a given id. Dies if it can't find the document. Returns the document in hashref form.

=head2 get_p

    $couch->get_p($id);

See L<\"get">, except returns the result asynchronously in a L<Mojo::Promise>.

=head2 index

    $couch->index($idx);

Creates an index, where C<$idx> is a hashref following the CouchDB L<mango specification|https://docs.couchdb.org/en/stable/api/database/find.html#db-index>. Returns the result of the index creation.

=head2 index_p

    $couch->index_p($idx);

See L<\"index">, except returns the result asynchronously in a L<Mojo::Promise>.

=head2 new

    my $url   = 'https://127.0.0.1:5984/my_database';
    my $couch = Mojo::CouchDB->new($url, $username, $password);

Creates an instance of L<\"Mojo::CouchDB">. The URL specified must include the protocol either C<http> or C<https> as well as the port your CouchDB instance is using, and the name of the database you want to manipulate.

=head2 save

    $couch->save($document);

Saves a document (hashref) to the database. If the C<_id> field is provided, it will update if it already exists. If you provide both the C<_id> and C<_rev> field, that specific revision will be updated. Returns a hashref that corresponds to the CouchDB C<POST /{db}> specification.

=head2 save_p

    $couch->save_p($document);

Does the same as L<\"save"> but instead returns the result asynchronously in a L<Mojo::Promise>.

=head2 save_many

    $couch->save_many($documents);

Saves an arrayref of documents (hashrefs) to the database. Each document follows the same rules as L<\"save">. Returns an arrayref of the documents you saved with the C<_id> and C<_rev> fields filled.

=head2 save_many_p

    $couch->save_many_p($documents);

See L<\"save_many">, except returns the result asynchronously in a L<Mojo::Promise>.

=head1 API

=over 2

=item * L<Mojo::CouchDB>

=back

=head1 AUTHOR

Rawley Fowler, C<rawleyfowler@proton.me>.

=head1 CREDITS

=over 2

=back

=head1 LICENSE

Copyright (C) 2023, Rawley Fowler and contributors.

This program is free software, you can redistribute it and/or modify it under the terms of the Artistic License version 2.0.

=head1 SEE ALSO

L<https://mojolicious.org>.

=cut
