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

## dynamodb\_local

Use a local DynamoDB server - see ["DYNAMODB LOCAL"](#dynamodb-local).

## client\_class

## host

## port

## ssl

See ["CLIENT CONFIGURATION"](#client-configuration).

## client\_attr

## table\_name\_method

## create\_table\_method

## client\_builder\_method

## client\_args\_method

Parameters you can use if you want to rename the various attributes and methods that are added to your class by this role.

# ATTRIBUTES

Following are attributes that will be added to your consuming class.

## dynamo\_db\_client

This role adds an attribute named "dynamo\_db\_client" to your consuming class.  This attribute holds an instance of Amazon::DynamoDB that will be used to communicate with the DynamoDB service.  See ["CLIENT CONFIGURATION"](#client-configuration) for more details.

You can change this attribute's name via the client\_attr parameter.

# METHODS

Following are methods that will be added to your consuming class.

## $obj->store(\[ dynamo\_db\_client => $client \]\[, async => 1\])

Object method.  Stores the packed Moose object to DynamoDb.  Accepts 2 optional parameters:

- dynamo\_db\_client - Directly provide a Amazon::DynamoDB object, instead of using the dynamo\_db\_client attribute.
- async - Don't wait for the operation to complete, return a Future object instead.

## $obj = $class->load($key, \[, dynamo\_db\_client => $client \]\[, inject => { key => val, ... } \])

Class method.  Queries DynamoDB with a primary key, and returns a new Moose object built from the resulting data.

The first argument is the primary key to use, and is required.

Optional parameters can be specified following the key:

- dynamo\_db\_client - Directly provide a Amazon::DynamoDB object, instead of trying to build one using the class' configuration.
- inject - supply additional arguments to the class' new function, or override ones from the resulting data.

## $class->dynamo\_db\_create\_table(\[, dynamo\_db\_client => $client \]\[ ReadCapacityUnits => X, ... \])

Class method.  Wrapper for [Amazon::DynamoDB](https://metacpan.org/pod/Amazon::DynamoDB)'s create\_table method, with the table name and key already setup.

Takes in dynamo\_db\_client as an optional parameter, all other parameters are passed to Amazon::DynamoDB.

You can change this method's name via the create\_table\_method parameter.

## $client = $class->\_build\_dynamo\_db\_client()

See ["CLIENT CONFIGURATION"](#client-configuration).

You can change this method's name via the client\_builder\_method parameter.

## $args = $class->dynamo\_db\_client\_args()

See ["CLIENT CONFIGURATION"](#client-configuration)

You can change this method's name via the client\_args\_method parameter.

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

You can change this method's name via the table\_name\_method parameter.

# CLIENT CONFIGURATION

There are a handful ways to configure how this module sets up a client to talk to DynamoDB:

A) Do nothing, in which case an [Amazon::DynamoDB](https://metacpan.org/pod/Amazon::DynamoDB) object will be automatically created for you using configuration parameters gleaned from [AWS::CLI::Config](https://metacpan.org/pod/AWS::CLI::Config).

B) Pass your own [Amazon::DynamoDB](https://metacpan.org/pod/Amazon::DynamoDB) client object at every call, e.g.

    my $client = Amazon::DynamoDB(...);
    my $obj    = MyDoc->new(...);
    $obj->store(dynamo_db_client => $client);
    my $obj2 = MyDoc->load(dynamo_db_client => $client);

C) Set some [Amazon::DynamoDB](https://metacpan.org/pod/Amazon::DynamoDB) parameters when consuming the role.  The following are available: host, port, ssl.

    package MyDoc;
    use Moose;
    use MooseX::Storage;

    with Storage(io => [ 'AmazonDynamoDB' => {
        table_name => 'my_docs',
        key_attr   => 'doc_id',
        host       => $ENV{DYNAMODB_HOST},
        port       => $ENV{DYNAMODB_PORT},
        ssl        => $ENV{DYNAMODB_SSL},
    }]);

D) Override the dynamo\_db\_client\_args method in your class to provide your own parameters to [Amazon::DynamoDB](https://metacpan.org/pod/Amazon::DynamoDB)'s constructor.  Note that you can also set the client\_class parameter when consuming the role if you want to pass these args to a class other than [Amazon::DynamoDB](https://metacpan.org/pod/Amazon::DynamoDB) - this could be useful in tests.  Objects instantiated using client\_class must provide the get\_item and put\_item methods.

    package MyDoc;
    use Moose;
    use MooseX::Storage;

    with Storage(io => [ 'AmazonDynamoDB' => {
        table_name   => 'my_docs',
        key_attr     => 'doc_id',
        client_class => $ENV{DEVELOPMENT} ? 'MyTestClass' : 'Amazon::DynamoDB',
    }]);

    sub dynamo_db_client_args {
        my $class = shift;
        return {
              access_key => 'my access key',
              secret_key => 'my secret key',
              host       => 'dynamodb.us-west-1.amazonaws.com',
              ssl        => 1,
        };
    }

E) Override the \_build\_dynamo\_db\_client method in your class to provide your own client object.  The returned object must provide the get\_item and put\_item methods.

    package MyDoc;
    ...
    sub _build_dynamo_db_client {
        my $class = shift;
        return Amazon::DynamoDB->new(
            %{ My::Config::Class->dynamo_db_config },
        );
    }

# DYNAMODB LOCAL

If you're using this module, you might want to check out [DynamoDB Local](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Tools.DynamoDBLocal.html).  For instance, you might want your development code to hit a local server and your production code to go to Amazon.  This role has a dynamodb\_local parameter you can use to make this easier.

    package MyDoc;
    use Moose;
    use MooseX::Storage;

    with Storage(io => [ 'AmazonDynamoDB' => {
        table_name     => 'my_docs',
        key_attr       => 'doc_id',
        dynamodb_local => $ENV{DEVELOPMENT} ? 1 : 0,
    }]);

Having a true value for dynamodb\_local is equivalent to:

    with Storage(io => [ 'AmazonDynamoDB' => {
        ...
        host       => 'localhost',
        port       => '8000',
        ssl        => 0,
    }]);

# NOTES

## format level (freeze/thaw)

Note that this role does not need you to implement a 'format' level for your object, i.e freeze/thaw.  You can add one if you want it for other purposes.

## How references are stored

When communicating with the AWS service, the Amazon::DynamoDB code is not handling arrayrefs correctly (they can be returned out-of-order) or hashrefs at all.  I've added a simple JSON level when encountering references - it should work seamlessly in your Perl code, but if you look up the data directly in DynamoDB you'll see complex data structures stored as JSON strings.

I'm hoping to get this fixed.

# BUGS

See ["How references are stored"](#how-references-are-stored).

# SEE ALSO

- [Moose](https://metacpan.org/pod/Moose)
- [MooseX::Storage](https://metacpan.org/pod/MooseX::Storage)
- [Amazon's DynamoDB Homepage](http://aws.amazon.com/dynamodb/)
- [Amazon::DynamoDB](https://metacpan.org/pod/Amazon::DynamoDB) - Perl DynamoDB client.
- [AWS::CLI::Config](https://metacpan.org/pod/AWS::CLI::Config) - how configuration is done by default.

# AUTHOR

Steve Caldwell <scaldwell@gmail.com>

# COPYRIGHT

Copyright 2015- Steve Caldwell <scaldwell@gmail.com>

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# ACKNOWLEDGEMENTS

Thanks to [Campus Explorer](http://www.campusexplorer.com), who allowed me to release this code as open source.
