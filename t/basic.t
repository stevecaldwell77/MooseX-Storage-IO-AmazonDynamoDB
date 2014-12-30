use lib 'tlib';
use strict;
use Test::Most;

use AWS::CLI::Config;

#
# This runs a basic set of tests, running against a real DynamoDB server.
# It will only be run if the RUN_DYNAMODB_TESTS envar is set.
# BE AWARE THIS WILL COST YOU MONEY EVERY TIME IT RUNS.
#

{
    package MyDoc;
    use Moose;
    use MooseX::Storage;

    with Storage(io => 'AmazonDynamoDB');

    has 'title'   => (is => 'rw', isa => 'Str');
    has 'body'    => (is => 'rw', isa => 'Str');
    has 'tags'    => (is => 'rw', isa => 'ArrayRef');
    has 'authors' => (is => 'rw', isa => 'HashRef');
}

SKIP: {
    skip 'RUN_DYNAMODB_TESTS envar not set, '
        . 'skipping tests against real DynamoDB server', 1
        if !$ENV{RUN_DYNAMODB_TESTS};

    my $table_name = 'moosex-storage-io-amazondynamodb-'.time;

    setup($table_name);

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
        table_name => $table_name,
        key        => {
            mykey => $key
        },
    );

    my $doc2 = MyDoc->load(
        table_name => $table_name,
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

    teardown($table_name);
}

done_testing;

sub setup {
    my ($table_name) = @_;

    my $client = client();

    $client->create_table(
        TableName            => $table_name,
        AttributeDefinitions => {
            mykey => 'S',
        },
        KeySchema            => ['mykey'],
        ReadCapacityUnits    => 2,
        WriteCapacityUnits   => 2,
    )->get();

    $client->wait_for_table_status(TableName => $table_name);
}

sub teardown {
    my ($table_name) = @_;

    my $client = client();

    $client->delete_table(
        TableName => $table_name,
    );
}

sub client {
    my $region = AWS::CLI::Config::region;
    return Amazon::DynamoDB->new(
        access_key => AWS::CLI::Config::access_key_id,
        secret_key => AWS::CLI::Config::secret_access_key,
        host       => "dynamodb.$region.amazonaws.com",
        ssl        => 1,
    );
}
