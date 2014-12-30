use lib 'tlib';
use strict;
use Test::Most;

#
# This runs a basic set of tests, using a mocked DynamoDB client.
#

use TestDynamoDB;

$ENV{AWS_ACCESS_KEY_ID} = 'ABABABABABABABABABAB';
$ENV{AWS_SECRET_ACCESS_KEY} = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
$ENV{AWS_DEFAULT_REGION} = 'us-east-1';

my $table_name = 'moosex-storage-io-amazondynamodb-'.time;

{
    package MyDoc;
    use Moose;
    use MooseX::Storage;

    with Storage(io => [ 'AmazonDynamoDB' => {
        client_class => 'TestDynamoDB',
        table_name   => $table_name,
    }]);

    has 'title'   => (is => 'rw', isa => 'Str');
    has 'body'    => (is => 'rw', isa => 'Str');
    has 'tags'    => (is => 'rw', isa => 'ArrayRef');
    has 'authors' => (is => 'rw', isa => 'HashRef');
}

TestDynamoDB->create_table(
    table_name => $table_name,
    key_name   => 'mykey',
);

my $doc = MyDoc->new(
    title    => 'Foo',
    body     => 'blah blah',
    tags     => [qw(horse yellow angry)],
    authors  => {
        jdoe => {
            name  => 'John Doe',
            email => 'jdoe@gmail.com',
            roles => [qw(author reader)],
        },
        bsmith => {
            name  => 'Bob Smith',
            email => 'bsmith@yahoo.com',
            roles => [qw(editor reader)],
        },
    },
);

my $key = 'a-unique-key';

$doc->store(
    key        => {
        mykey => $key
    },
);

my $doc2 = MyDoc->load(
    key        => {
        mykey => $key
    },
);

cmp_deeply(
    $doc2,
    all(
        isa('MyDoc'),
        methods(
            title    => 'Foo',
            body     => 'blah blah',
            tags     => [qw(horse yellow angry)],
            authors  => {
                jdoe => {
                    name  => 'John Doe',
                    email => 'jdoe@gmail.com',
                    roles => [qw(author reader)],
                },
                bsmith => {
                    name  => 'Bob Smith',
                    email => 'bsmith@yahoo.com',
                    roles => [qw(editor reader)],
                },
            },
        ),
    ),
    'retrieved document looks good',
);

done_testing;
