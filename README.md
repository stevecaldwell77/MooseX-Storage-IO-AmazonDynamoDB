# NAME

MooseX::Storage::IO::AmazonDynamoDB - Save Moose objects to AWS's DynamoDB, via MooseX::Storage.

# SYNOPSIS

First, configure your Moose class via a call to Storage:

    package MyDoc;
    use Moose;
    use MooseX::Storage;

    with Storage(io => [ 'AmazonDynamoDB' => {
        table_name => 'my_docs',
        key_attr   => 'doc_id',
    }]);

    has 'doc_id'  => (is => 'ro', isa => 'Str', required => 1);
    has 'title'   => (is => 'rw', isa => 'Str');
    has 'body'    => (is => 'rw', isa => 'Str');
    has 'tags'    => (is => 'rw', isa => 'ArrayRef');
    has 'authors' => (is => 'rw', isa => 'HashRef');

    1;

Then create your table in DynamoDB.  You could also do this directly on AWS.

    MyDoc->dynamo_db_create_table();

Now you can store/load your class to DyanmoDB:

    use MyDoc;

    # Create a new instance of MyDoc
    my $doc = MyDoc->new(
        doc_id   => 'foo12',
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

    # Save it to DynamoDB
    $doc->store();

    # Load the saved data into a new instance
    my $doc2 = MyDoc->load('foo12');

    # This should say 'Bob Smith'
    print $doc2->authors->{bsmith}{name};

# DESCRIPTION

MooseX::Storage::IO::AmazonDynamoDB is a Moose role that provides an io layer for [MooseX::Storage](https://metacpan.org/pod/MooseX::Storage) to store/load your Moose objects to Amazon's DynamoDB NoSQL database service.

You should understand the basics of [Moose](https://metacpan.org/pod/Moose), [MooseX::Storage](https://metacpan.org/pod/MooseX::Storage), and [DynamoDB](http://aws.amazon.com/dynamodb/) before using this module.

This module uses [Amazon::DynamoDB](https://metacpan.org/pod/Amazon::DynamoDB) as its client library to the DynamoDB service.

By default it grabs authentication credentials using the same procedure as the AWS CLI, see [AWS::CLI::Config](https://metacpan.org/pod/AWS::CLI::Config).  You can customize this behavior - see ["CLIENT CONFIGURATION"](#client-configuration).

At a bare minimum the consuming class needs to tell this role what table to use and what field to use as a primary key - see ["table\_name"](#table_name) and ["key\_attr"](#key_attr).

# PARAMETERS

There are many parameters you can set when consuming this role that configure it in different ways.

## key\_attr

"key\_attr" is a required parameter when consuming this role.  It specifies an attribute in your class that will provide the primary key value for storing your object to DynamoDB.  Currently only single primary keys are supported, or what DynamoDB calls "Hash Type Primary Key" (see their [documentation](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DataModel.html#DataModel.PrimaryKey)).  See the ["SYNOPSIS"](#synopsis) for an example.

## table\_name

Specifies the name of the DynamoDB table to use for your objects - see the example in the ["SYNOPSIS"](#synopsis).  Alternatively, you can return the table name via a class method - see ["dynamo\_db\_table\_name"](#dynamo_db_table_name).

## client\_class, host, port, ssl

See ["CLIENT CONFIGURATION"](#client-configuration).

## table\_name\_method

If you want to rename the ["dynamo\_db\_table\_name"](#dynamo_db_table_name) method.

## create\_table\_method

If you want to rename the ["dynamo\_db\_create\_table"](#dynamo_db_create_table) method.

## client\_attr

If you want to rename the ["dynamo\_db\_client"](#dynamo_db_client) attribute.

## client\_class\_method

If you want to rename the ["dynamo\_db\_client\_class"](#dynamo_db_client_class) method.

## client\_args\_method

If you want to rename the ["dynamo\_db\_client\_args"](#dynamo_db_client_args) method.

# ATTRIBUTES

Following are attributes that will be added to your consuming class.

## dynamo\_db\_client

This role adds an attribute named "dynamo\_db\_client" to your consuming class.  This attribute holds an instance of Amazon::DynamoDB that will be used to communicate with the DynamoDB service.  See ["CLIENT CONFIGURATION"](#client-configuration) for more details.

Note that you can change the name of this attribute when consuming this role via the ["client\_attr"](#client_attr) parameter.

# METHODS

Following are methods that will be added to your consuming class.

## $obj->store(\[ dynamo\_db\_client => $client \]\[, async => 1\])

Object method.  Stores the packed Moose object to DynamoDb.  Accepts 2 optional parameters:

- dynamo\_db\_client - Directly provide a Amazon::DynamoDB object, instead of using the dynamo\_db\_client attribute.
- async - Don't wait for the operation to complete, return a Future object instead.

## $obj = $class->load($key, \[, dynamo\_db\_client => $client \]\[, inject = { key => val, ... } \])

Class method.  Queries DynamoDB with a primary key, and returns a new Moose object built from the resulting data.

The first argument is the primary key to use, and is required.

Optional parameters can be specified following the key:

- dynamo\_db\_client - Directly provide a Amazon::DynamoDB object, instead of trying to build one using the class' configuration.
- inject - supply additional arguments to the class' new function, or override ones from the resulting data.

## $class->dynamo\_db\_create\_table(\[, dynamo\_db\_client => $client \]\[ ReadCapacityUnits => X, ... \])

Class method.  Wrapper for [Amazon::DynamoDB](https://metacpan.org/pod/Amazon::DynamoDB)'s create\_table method, with the table name and key already setup.

Takes in dynamo\_db\_client as an optional parameter, all other parameters are passed to Amazon::DynamoDB.

## $client\_class = $class->dynamo\_db\_client\_class()

See ["CLIENT CONFIGURATION"](#client-configuration)

## $args = $class->dynamo\_db\_client\_args()

See ["CLIENT CONFIGURATION"](#client-configuration)

# HOOKS

Following are methods that your consuming class can provide.

## dynamo\_db\_table\_name

A class method that will return the table name to use.  This method will be called if the ["table\_name"](#table_name) parameter is not set.  So you could rewrite the Moose class in the ["SYNOPSIS"](#synopsis) like this:

    package MyDoc;
    use Moose;
    use MooseX::Storage;

    with Storage(io => [ 'AmazonDynamoDB' => {
        key_attr   => 'doc_id',
    }]);

    ...

    sub dynamo_db_table_name {
        my $class = shift;
        return $ENV{DEVELOPMENT} ? 'my_docs_dev' : 'my_docs';
    }

You can also change the actual method name via the ["table\_name\_method"](#table_name_method) parameter.

# CLIENT CONFIGURATION

# NOTES

## format level (freeze/thaw)

Note that this role does not need you to implement a 'format' level for your object, i.e freeze/thaw.  You can add one if you want it for other purposes.

## How references are stored

When communicating with the AWS service, the Amazon::DynamoDB code is not handling arrayrefs correctly (they can be returned out-of-order) or hashrefs at all.  I've added a simple JSON level when encountering references - it should work seamlessly in your Perl code, but if you look up the data directly in DynamoDB you'll see complex data structures stored as JSON strings.

I'm hoping to get this fixed.

# BUGS

See ["How references are stored"](#how-references-are-stored).

# AUTHOR

Steve Caldwell <scaldwell@gmail.com>

# COPYRIGHT

Copyright 2015- Steve Caldwell <scaldwell@gmail.com>

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO

- [Moose](https://metacpan.org/pod/Moose)
- [MooseX::Storage](https://metacpan.org/pod/MooseX::Storage)
- [Amazon's DynamoDB Homepage](http://aws.amazon.com/dynamodb/)
- [Amazon::DynamoDB](https://metacpan.org/pod/Amazon::DynamoDB) - Perl DynamoDB client.
- [AWS::CLI::Config](https://metacpan.org/pod/AWS::CLI::Config) - how configuration is done by default.
