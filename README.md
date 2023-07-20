# Mojo::CouchDB

A Mojolicious wrapper around [Mojo::UserAgent](https://docs.mojolicious.org/Mojo/UserAgent) that makes using [CouchDB](https://couchdb.apache.org/) from
Perl, a lot of fun.

```perl
use Mojo::CouchDB;

# Create a CouchDB instance
my $couch = Mojo::CouchDB->new('http://localhost:6984', 'username', 'password');
my $db = $couch->db('books');

$db->create_db; # Create the database on the server

# Make a document
my $book = {
	title => 'Nineteen Eighty Four',
	author => 'George Orwell'
};

# Save your document to the database
$book = $db->save($book);

# If _id is assigned to a hashref, save will update rather than create
say $book->{_id}; # Assigned when saving or getting
$book->{title} = 'Dune';
$book->{author} = 'Frank Herbert'

# Re-save to update the document
$book = $db->save($book);

# Get the document as a hashref
my $dune = $db->get($book->{_id});

# You can also save many documents at a time
my $books = $db->save_many([{title => 'book', author => 'John'}, { title => 'foo', author => 'bar' }])->{docs};
```

## Installation

```bash
$ cpanm Mojo::CouchDB
```

## Basics

This is an example of a [Mojolicious::Lite](https://docs.mojolicious.org/Mojolicious/Lite) application using
[Mojo::CouchDB](#).

```perl
use v5.36;
use Mojolicious::Lite -signatures;
use Mojo::CouchDB;

my $couch = Mojo::Couch->new('http://127.0.0.1:5984', 'username', 'password');

helper user_db => sub { state $user_db = $couch->db('users') };

get '/:user' => sub {
	my $c    = shift;
	my $user = $c->user_db->get($c->param('user'))
		|| return $c->rendered(404);
	return $c->render(json => $user);
};

app->start;
```

It is recommended to use a helper when using Mojo::CouchDB with Mojolicious.

## Author

Rawley Fowler

## Credits

Sebastion Riedel (the creator of Mojolicious).

The Apache Foundation for making CouchDB.

## Copyright and License

Copyright (C) 2023, Rawley Fowler

This library is free software; you may distribute, and/or modify it under the terms of the Artistic License version 2.0.
