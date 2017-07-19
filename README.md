# NAME

MooseX::Storage::IO::AmazonDynamoDB - Store and retrieve Moose objects to AWS's DynamoDB, via MooseX::Storage.

# SYNOPSIS

First, create a table in DynamoDB. Currently only single-keyed tables are supported.

    aws dynamodb create-table \
      --table-name my_docs \
      --key-schema "AttributeName=doc_id,KeyType=HASH" \
      --attribute-definitions "AttributeName=doc_id,AttributeType=S" \
      --provisioned-throughput "ReadCapacityUnits=2,WriteCapacityUnits=2"

Then, configure your Moose class via a call to Storage:

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

This module uses [Paws](https://metacpan.org/pod/Paws) as its client library to the DynamoDB service, via [PawsX::DynamoDB::DocumentClient](https://metacpan.org/pod/PawsX::DynamoDB::DocumentClient). By default it uses the Paws configuration defaults (region, credentials, etc.). You can customize this behavior - see ["CLIENT CONFIGURATION"](#client-configuration).

At a bare minimum the consuming class needs to tell this role what table to use and what field to use as a primary key - see ["table\_name"](#table_name) and ["key\_attr"](#key_attr).

## BREAKING CHANGES IN v0.07

v0.07 transitioned the underlying DynamoDB client from [Amazon::DynamoDB](https://metacpan.org/pod/Amazon::DynamoDB) to [Paws::Dynamodb](https://metacpan.org/pod/Paws::Dynamodb), in order to stay more up-to-date with AWS features. Any existing code which customized the client configuration will break when upgrading to v0.07. Support for creating tables was also removed.

The following role parameters were removed: client\_attr, client\_builder\_method, client\_class, client\_args\_method, host, port, ssl, dynamodb\_local, create\_table\_method.

The following attibutes were removed: dynamo\_db\_client

The following methods were removed: build\_dynamo\_db\_client, dynamo\_db\_client\_args, dynamo\_db\_create\_table

The dynamo\_db\_client parameter to load() was removed, in favor of dynamodb\_document\_client.

The dynamo\_db\_client and async parameters to store() were removed.

Please see See ["CLIENT CONFIGURATION"](#client-configuration) for details on how to configure your client in v0.07 and above.

# PARAMETERS

There are many parameters you can set when consuming this role that configure it in different ways.

## REQUIRED

### key\_attr

"key\_attr" is a required parameter when consuming this role.  It specifies an attribute in your class that will provide the primary key value for storing your object to DynamoDB.  Currently only single primary keys are supported, or what DynamoDB calls "Hash Type Primary Key" (see their [documentation](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DataModel.html#DataModel.PrimaryKey)).  See the ["SYNOPSIS"](#synopsis) for an example.

## OPTIONAL

### table\_name

Specifies the name of the DynamoDB table to use for your objects - see the example in the ["SYNOPSIS"](#synopsis).  Alternatively, you can return the table name via a class method - see ["dynamo\_db\_table\_name"](#dynamo_db_table_name).

### table\_name\_method

By default, this role will add a method named 'dynamo\_db\_table\_name' to your class (see below for method description). If you want to use a different name for this method (e.g., because it conflicts with an existing method), you can change it via this parameter.

### document\_client\_attribute\_name

By default, this role adds an attribute to your class named 'dynamodb\_document\_client' (see below for attribute description). If you want to use a different name for this attribute, you can change it via this parameter.

### parameter document\_client\_builder

Allows customization of the PawsX::DynamoDB::DocumentClient object used to interact with DynamoDB. See ["CLIENT CONFIGURATION"](#client-configuration) for more details.

# ATTRIBUTES

## dynamodb\_document\_client

This role adds an attribute named "dynamodb\_document\_client" to your consuming class.  This attribute holds an instance of [PawsX::DynamoDB::DocumentClient](https://metacpan.org/pod/PawsX::DynamoDB::DocumentClient) that will be used to communicate with the DynamoDB service.

You can change this attribute's name via the document\_client\_attribute\_name parameter.

The attribute is lazily built via document\_client\_builder. See ["CLIENT CONFIGURATION"](#client-configuration) for more details.

# METHODS

Following are methods that will be added to your consuming class.

## $obj->store()

Object method.  Stores the packed Moose object to DynamoDb.

## $obj = $class->load($key, \[, dynamodb\_document\_client => $client \]\[, inject => { key => val, ... } \])

Class method.  Queries DynamoDB with a primary key, and returns a new Moose object built from the resulting data.  Returns undefined if they key could not be found in DyanmoDB.

The first argument is the primary key to use, and is required.

Optional parameters can be specified following the key:

- dynamodb\_document\_client - Directly provide a PawsX::DynamoDB::DocumentClient object, instead of trying to build one using the class' configuration.
- inject - supply additional arguments to the class' new function, or override ones from the resulting data.

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

This role uses the 'dynamodb\_document\_client' attribute (assuming you didn't rename it via 'document\_client\_attribute\_name') to interact with DynamoDB. This attribute is lazily built, and should hold an instance of [PawsX::DynamoDB::DocumentClient](https://metacpan.org/pod/PawsX::DynamoDB::DocumentClient).

The client is built by a coderef that is stored in the role's document\_client\_builder parameter. By default, that coderef is simply:

    sub { return PawsX::DynamoDB::DocumentClient->new(); }

If you need to customize the client, you do so by providing your own builder coderef. For instance, you could set the region directly:

    package MyDoc;
    use Moose;
    use MooseX::Storage;
    use PawsX::DynamoDB::DocumentClient;

    with Storage(io => [ 'AmazonDynamoDB' => {
        table_name              => 'my_docs',
        key_attr                => 'doc_id',
        document_client_builder => \&_build_document_client,
    }]);

    sub _build_document_client {
        my $region = get_my_region_somehow();
        return PawsX::DynamoDB::DocumentClient->new(region => $region);
    }

See ["DYNAMODB LOCAL"](#dynamodb-local) for an example of configuring our Paws client to run against a locally running dynamodb clone.

Note: the dynamodb\_document\_client attribute is not typed to a strict isa('PawsX::DynamoDB::DocumentClient'), but instead requires an object that has a 'get' and 'put' method. So you can provide some kind of mocked object, but that is left as an exercise to the reader - although examples are welcome!

# DYNAMODB LOCAL

Here's an example of configuring your client to run against DynamoDB Local based on an environment variable. Make sure you've read ["CLIENT CONFIGURATION"](#client-configuration). More information about DynamoDB Local can be found at [AWS](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBLocal.html).

    package MyDoc;
    use Moose;
    use MooseX::Storage;
    use Paws;
    use Paws::Credential::Explicit;
    use PawsX::DynamoDB::DocumentClient;

    with Storage(io => [ 'AmazonDynamoDB' => {
        table_name              => $table_name,
        key_attr                => 'doc_id',
        document_client_builder => \&_build_document_client,
    }]);

    sub _build_document_client {
        if ($ENV{DYNAMODB_LOCAL}) {
            my $dynamodb = Paws->service(
                'DynamoDB',
                region       => 'us-east-1',
                region_rules => [ { uri => 'http://localhost:8000'} ],
                credentials  => Paws::Credential::Explicit->new(
                    access_key => 'XXXXXXXXX',
                    secret_key => 'YYYYYYYYY',
                ),
                max_attempts => 2,
            );
            return PawsX::DynamoDB::DocumentClient->new(dynamodb => $dynamodb);
        }
        return PawsX::DynamoDB::DocumentClient->new();
    }

# NOTES

## Strongly consistent reads

When executing load(), this module will always use strongly consistent reads when calling DynamoDB's GetItem operation.  Read about DyanmoDB's consistency model in their [FAQ](http://aws.amazon.com/dynamodb/faqs/) to learn more.

## Format level (freeze/thaw)

Note that this role does not need you to implement a 'format' level for your object, i.e freeze/thaw.  You can add one if you want it for other purposes.

## Pre-v0.07 objects

Before v0.07, this module stored objects to DyanmoDB using [Amazon::DynamoDB](https://metacpan.org/pod/Amazon::DynamoDB). It worked around some issues with that module by serializing certain data types to JSON. Objects stored using this old system will be deserialized correctly.

# SEE ALSO

- [Moose](https://metacpan.org/pod/Moose)
- [MooseX::Storage](https://metacpan.org/pod/MooseX::Storage)
- [Amazon's DynamoDB Homepage](http://aws.amazon.com/dynamodb/)
- [PawsX::DynamoDB::DocumentClient](https://metacpan.org/pod/PawsX::DynamoDB::DocumentClient) - DynamoDB client.
- [Paws](https://metacpan.org/pod/Paws) - AWS library.

# AUTHOR

Steve Caldwell <scaldwell@gmail.com>

# COPYRIGHT

Copyright 2015- Steve Caldwell <scaldwell@gmail.com>

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# ACKNOWLEDGEMENTS

Thanks to [Campus Explorer](http://www.campusexplorer.com), who allowed me to release this code as open source.
