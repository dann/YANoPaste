use strict;
use warnings;
use File::Spec;
use File::Basename;
use local::lib File::Spec->catdir(dirname(__FILE__), 'extlib');
use lib File::Spec->catdir(dirname(__FILE__), 'lib');

use Web::Dispatcher::Simple;
use DBIx::Simple::DataSection;
use Data::Section::Simple qw(get_data_section);
use Text::Xslate;
use Digest::MD5;
use Plack::Builder;
use Cwd qw/realpath/;
use File::Basename qw/dirname/;

our $VERSION = 0.01;

my $_DB;
my $_RENDERER;

# DB access
sub db {
    return $_DB if $_DB;
    my $db_path = File::Spec->catfile( root_dir(), "data", "nonopaste.db" );
    my $db = DBIx::Simple::DataSection->connect( "dbi:SQLite:dbname=$db_path",
        "", "", { RaiseError => 1, AutoCommit => 1 } );
    $db->query_by_sql('create_entries_table.sql');
    $db->query_by_sql('make_index_for_entries.sql');
    $_DB = $db;
    $db;
}

# Renderer
sub renderer {
    return $_RENDERER if $_RENDERER;
    my $vpath = Data::Section::Simple->new()->get_data_section();
    no warnings 'redefine';
    my $renderer = Text::Xslate->new(
        path => [ $vpath ],
        syntax    => 'TTerse',
        cache_dir  => File::Spec->catfile(root_dir(),".xslate_cache"),
        cache      => 1,
    );
    $_RENDERER = $renderer; 
    $renderer;
}

sub root_dir {
    my @caller = caller; 
    my $root_dir = dirname( realpath($caller[1]) ); 
    $root_dir;
}

# Logic 
sub add_entry {
    my ( $body, $nick ) = @_;
    $body = ''           if !defined $body;
    $nick = 'anonymouse' if !defined $nick;

    my $id = substr Digest::MD5::md5_hex(
        $$ . 'yanopaste' . join( "\0", @_ ) . rand(1000) ), 0, 16;
    my $rs
        = db()->query_by_sql( 'insert_entry.sql', ( $id, $nick, $body ) );
    return ( $rs->rows == 1 ) ? $id : 0;
}

sub entry_list {
    my $offset = shift || 0;
    my $rs = db()->query_by_sql( 'get_entry_list.sql', $offset );
    my @ret;
    while ( my $row = $rs->hash ) {
        push @ret, $row;
        last if @ret == 10;
    }
    my $next = $rs->hash;
    return \@ret, $next;
}

sub retrieve_entry {
    my $id = shift;
    return db()->query_by_sql( 'get_entry.sql', $id )->hash;
}

# Helper
sub render {
    my ( $template_name, $params, $req ) = @_;
    my $res = $req->new_response(200);
    $params ||= {};
    $params->{req} = $req;
    my $body = renderer()->render($template_name, $params );
    $res->body($body);
    $res;
}

sub redirect {
    my $location = shift;
    return [302, ['Location' => $location], []]
}

# Routing
my $app = router {
    get '/' => sub {
        my ( $req, $match ) = @_;
        my $offset = $req->param('offset') ? $req->param('offset') : 0;
        my ( $entries, $next ) = entry_list($offset);
        render( 'index.tt', { entries => $entries, next => $next, offset=> $offset,  }, $req ); 
    },
    post '/add' => sub {
        my ($req, $match) = @_;
        if ( $req->param('body') ) {
            my $id = add_entry( $req->param('body'), $req->param('nick') );
            return redirect( $req->uri_for( '/entry/' . $id ) ) if $id;
        }
        my ( $entries, $next ) = entry_list();
        return render( 'index.tt', { entries => $entries,next=> $next, offset=> 0}, $req );
    },
    get '/entry/{id:[0-9a-f]{16}}' => sub {
        my ( $req, $match ) = @_;
        my $entry = retrieve_entry( $match->{id} );
        return not_found() unless $entry;
        render( 'entry.tt', { entry => $entry, offset=>0}, $req );
    }
};

$app = builder {
    enable 'Plack::Middleware::Static',
        path => qr{^/(favicon\.ico$|static/)},
        root => File::Spec->catfile(root_dir(), 'htdocs');
    $app; 
};

return $app;

__DATA__
@@ create_entries_table.sql
CREATE TABLE IF NOT EXISTS entries (
    id VARCHAR(255) NOT NULL PRIMARY KEY,
    nick VARCHAR(255) NOT NULL,
    body TEXT,
    ctime DATETIME NOT NULL
)

@@ make_index_for_entries.sql
CREATE INDEX IF NOT EXISTS index_ctime ON entries ( ctime )

@@ insert_entry.sql
INSERT INTO entries ( id, nick, body, ctime ) values ( ?, ?, ?, DATETIME('now') )

@@ get_entry_list.sql
SELECT id,nick,body,ctime FROM entries ORDER BY ctime DESC LIMIT ?,11

@@ get_entry.sql
SELECT id,nick,body,ctime FROM entries WHERE id = ?

@@ header.tt
<html>
<head>
<title>YANoPaste: Yet Another NoPaste</title>
<link rel="stylesheet" type="text/css" href="[% req.uri_for('/static/js/prettify/prettify.css') %]" />
<link rel="stylesheet" type="text/css" href="[% req.uri_for('/static/css/ui-lightness/jquery-ui-1.8.2.custom.css') %]" />
<link rel="stylesheet" type="text/css" href="[% req.uri_for('/static/css/default.css') %]" />
</head>
<body>
<div id="container">
<div id="header">
<h1 class="title"><a href="[% req.uri_for('/') %]">Yet Another NoPaste</a></h1>
<div class="welcome">
<ul>
<li><a href="[% req.uri_for('/') %]">TOP</a></li>
</ul>
</div>
</div>
<div id="content">

@@ footer.tt
</div>
</div>
<script src="[% req.uri_for('/static/js/jquery-1.4.2.min.js') %]" type="text/javascript"></script>
<script src="[% req.uri_for('/static/js/jstorage.js') %]" type="text/javascript"></script>
<script src="[% req.uri_for('/static/js/prettify/prettify.js') %]" type="text/javascript"></script>
<script type="text/javascript">
$(function() {
    prettyPrint();
});
</script>
</body>
</html>

@@ index.tt
[% INCLUDE 'header.tt' %]
<h2 class="subheader">New Entry</h2>
<form method="post" action="/add" id="nopaste">
<textarea name="body" rows="20" cols="60"></textarea>
<label for="nick">nick</label>
<input type="text" id="nick" name="nick" value="" size="21" />
<input type="submit" id="post_nopaste" value="POST" />
</form>

<h2 class="subheader">List</h2>
[% FOREACH entry IN entries %]
<div class="entry">
<pre class="prettyprint">
[% entry.body %]
</pre>
<div class="entry_meta"><a href="[% req.uri_for('/entry/',entry.id) %]" class="date">[% entry.ctime %]</a> / <span class="nick">[% entry.nick %]</span></div>
</div>
[% END %]

<p class="paging">
[% IF offset >= 10 %]
<a href="[% req.uri_for('/', [ 'offset' => (offset - 10) ] ) %]">Prev</a>
[% ELSIF $next %]
<a href="[% req.uri_for('/', [ 'offset' => (offset + 10) ] ) %]">Next</a>
[% END %]
</p>

[% INCLUDE 'footer.tt' %]

@@ entry.tt
[% INCLUDE 'header.tt' %]

<h2 class="subheader"><a href="[% req.uri_for('/entry/', entry.id) %]">[% req.uri_for('/entry/', entry.id) %]</a></h2>
<div class="entry">
<pre class="prettyprint">
[% entry.body %]
</pre>
<div class="entry_meta"><a href="[% req.uri_for('/entry/',entry.id) %]" class="date">[% entry.ctime %]</a> / <span class="nick">[% entry.nick %]</span></div>
</div>

[% INCLUDE 'footer.tt' %]
