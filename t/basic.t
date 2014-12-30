use lib 'tlib';
use strict;
use Test::More;

use TestDynamoDB;

$ENV{AWS_ACCESS_KEY_ID} = 'ABABABABABABABABABAB';
$ENV{AWS_SECRET_ACCESS_KEY} = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
$ENV{AWS_DEFAULT_REGION} = 'us-east-1';

{
    package MyDoc;
    use Moose;
    use MooseX::Storage;

    with Storage(io => [ 'AmazonDynamoDB' => {
        client_class => 'TestDynamoDB',
    }]);

    has 'title' => (is => 'rw', isa => 'Str');
    has 'body'  => (is => 'rw', isa => 'Str');
}

TestDynamoDB->create_table(
    table_name => 'mydoc',
    key_name   => 'mykey',
);

my $doc = MyDoc->new(title => 'Foo', body => 'blah blah');

my $key = 'a-unique-key';

$doc->store(
    table_name => 'mydoc',
    key        => {
        mykey => $key
    },
);

my $doc2 = MyDoc->load(
    table_name => 'mydoc',
    key        => {
        mykey => $key
    },
);

is($doc2->title, 'Foo', 'title retrieved correctly');
is($doc2->body, 'blah blah', 'body retrieved correctly');

done_testing;
