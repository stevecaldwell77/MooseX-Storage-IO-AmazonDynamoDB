package MooseX::Storage::IO::AmazonDynamoDB;
# ABSTRACT: Save Moose objects to AWS's DynamoDB, via MooseX::Storage.

use strict;
use 5.014;
our $VERSION = '0.01';

use Amazon::DynamoDB;
use AWS::CLI::Config;
use JSON::MaybeXS;
use Module::Runtime qw(use_module);
use MooseX::Role::Parameterized;
use MooseX::Storage;
use Types::Standard qw(Str HashRef HasMethods);
use namespace::autoclean;

parameter key_attr => (
    isa      => 'Str',
    required => 1,
);

parameter table_name => (
    isa     => 'Maybe[Str]',
    default => undef,
);

parameter table_name_method => (
    isa     => 'Str',
    default => 'dynamo_db_table_name',
);

parameter client_attr => (
    isa     => 'Str',
    default => 'dynamo_db_client',
);

parameter client_class => (
    isa     => 'Str',
    default => 'Amazon::DynamoDB',
);

parameter client_class_method => (
    isa     => 'Str',
    default => 'dynamo_db_client_class',
);

parameter client_args_method => (
    isa     => 'Str',
    default => 'dynamo_db_client_args',
);

parameter host => (
    isa     => 'Maybe[Str]',
    default => undef,
);

parameter port => (
    isa     => 'Maybe[Int]',
    default => undef,
);

parameter ssl => (
    isa     => 'Bool',
    default => 1,
);

parameter create_table_method => (
    isa     => 'Str',
    default => 'dynamo_db_create_table',
);

role {
    my $p = shift;

    requires 'pack';
    requires 'unpack';

    my $client_attr         = $p->client_attr;
    my $client_class_method = $p->client_class_method;
    my $client_args_method  = $p->client_args_method;

    my $build_client = sub {
        my $ref = shift;
        my $client_class = $ref->$client_class_method();
        use_module($client_class);
        my $client_args  = $ref->$client_args_method();
        return $client_class->new(%$client_args);
    };

    has $client_attr => (
        is      => 'ro',
        isa     => HasMethods[qw(get_item put_item)],
        lazy    => 1,
        traits  => [ 'DoNotSerialize' ],
        default => $build_client,
    );

    method $client_class_method => sub { $p->client_class };

    method $client_args_method => sub {
        my $region = AWS::CLI::Config::region;
        my $host = $p->host || "dynamodb.$region.amazonaws.com";
        return {
            access_key => AWS::CLI::Config::access_key_id,
            secret_key => AWS::CLI::Config::secret_access_key,
            host       => $host,
            port       => $p->port,
            ssl        => $p->ssl,
        };
    };

    my $get_table_name = sub {
        my $ref = shift;
        return $p->table_name if $p->table_name;
        if (my $method = $p->table_name_method) {
            return $ref->$method;
        }
        my $class = ref $ref || $ref;
        die "$class: no table name defined!";
    };

    method load => sub {
        my ( $class, $item_key, %args ) = @_;
        my $client = $args{dynamo_db_client} || $build_client->($class);
        my $inject = $args{inject}           || {};
        my $table_name = $get_table_name->($class);

        # TBD: handle failures

        my $unpacker = sub {
            my $packed = shift;

            # Refs are stored as JSON
            foreach my $key (%$packed) {
                my $value = $packed->{$key};
                if ($value && $value =~ /^\$json\$v(\d+)\$:(.+)$/) {
                    my ($version, $json) = ($1, $2);
                    state $coder = JSON::MaybeXS->new(utf8=>1);
                    $packed->{$key} = $coder->decode($json);
                }
            }

            return $class->unpack({
                %$packed,
                %$inject,
                $client_attr => $client,
            });
        };

        my $future = $client->get_item(
            $unpacker,
            TableName => $table_name,
            Key       => {
                $p->key_attr => $item_key,
            }
        );

        return $future->get();
    };

    method store => sub {
        my ( $self, %args ) = @_;
        my $client = $args{dynamo_db_client} || $self->$client_attr;
        my $async  = $args{async}            || 0;
        my $table_name = $get_table_name->($self);

        # TBD: handle failures

        # Store refs as JSON
        my $packed = $self->pack;
        foreach my $key (%$packed) {
            my $value = $packed->{$key};
            if (ref $value) {
                state $coder = JSON::MaybeXS->new(utf8=>1, canonical=>1);
                $packed->{$key} = '$json$v1$:'.$coder->encode($value);
            }
        }

        my $future = $client->put_item(
            TableName => $table_name,
            Item      => $packed,
        );

        if ($async) {
            return $future;
        }

        return $future->get();
    };

    method $p->create_table_method => sub {
        my ( $class, %args ) = @_;
        my $client = delete $args{dynamo_db_client}
                     || $build_client->($class);

        my $table_name = $get_table_name->($class);
        my $key_name   = $p->key_attr;

        $client->create_table(
            TableName            => $table_name,
            AttributeDefinitions => {
                $key_name => 'S',
            },
            KeySchema            => [$key_name],
            ReadCapacityUnits    => 2,
            WriteCapacityUnits   => 2,
            %args,
        )->get();

        $client->wait_for_table_status(TableName => $table_name);
    };
};

1;
__END__

=encoding utf-8

=head1 SYNOPSIS

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

=head1 DESCRIPTION

MooseX::Storage::IO::AmazonDynamoDB is a Moose role that provides an io layer for L<MooseX::Storage> to store/load your Moose objects to Amazon's DynamoDB NoSQL database service.

You should understand the basics of both L<MooseX::Storage> and L<DynamoDB|http://aws.amazon.com/dynamodb/> before using this module.

This module uses L<Amazon::DynamoDB> as its client library to the DynamoDB service.

By default it grabs authentication credentials using the same procedure as the AWS CLI, see L<AWS::CLI::Config>.  You can customize this behavior - see L<"CLIENT CONFIGURATION">.

At a bare minimum the consuming class needs to tell this role what table to use and what field to use as a primary key - see L<"table_name"> and L<"key_attr">.

=head1 PARAMETERS

There are many parameters you can set when consuming this role that configure it in different ways.

=head2 key_attr

"key_attr" is a required parameter when consuming this role.  It specifies an attribute in your class that will provide the primary key value for storing your object to DynamoDB.  Currently only single primary keys are supported, or what DynamoDB calls "Hash Type Primary Key" (see their L<documentation|http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DataModel.html#DataModel.PrimaryKey>).  See the L<"SYNOPSIS"> for an example.

=head2 table_name

Specifies the name of the DynamoDB table to use for your objects - see the example in the L<"SYNOPSIS">.  Alternatively, you can return the table name via a class method - see L<"dynamo_db_table_name">.

=head2 client_class, host, port, ssl

See L<"CLIENT CONFIGURATION">.

=head2 table_name_method

If you want to rename the L<"dynamo_db_table_name"> method.

=head2 create_table_method

If you want to rename the L<"dynamo_db_create_table"> method.

=head2 client_attr

If you want to rename the L<"dynamo_db_client"> attribute.

=head2 client_class_method

If you want to rename the L<"dynamo_db_client_class"> method.

=head2 client_args_method

If you want to rename the L<"dynamo_db_client_args"> method.

=head1 ATTRIBUTES

Following are attributes that will be added to your consuming class.

=head2 dynamo_db_client

This role adds an attribute named "dynamo_db_client" to your consuming class.  This attribute holds an instance of Amazon::DynamoDB that will be used to communicate with the DynamoDB service.  See L<"CLIENT CONFIGURATION"> for more details.

Note that you can change the name of this attribute when consuming this role via the L<"client_attr"> parameter.

=head1 METHODS

Following are methods that will be added to your consuming class.

=head2 $obj->store([ dynamo_db_client => $client ][, async => 1])

Object method.  Store the packed Moose object to DynamoDb.  Accepts 2 optional parameters:

=for :list
* dynamo_db_client - Directly provide a Amazon::DynamoDB object, instead of using the dynamo_db_client attribute.
* async - Don't wait for the operation to complete, return a Future object instead.

=head2 $obj = $class->load($key, [, dynamo_db_client => $client ][, inject = { key => val, ... } ])

Class method.  Query DynamoDB with a primary key, and return a new Moose object built from the resulting data.

The first argument is the primary key to use, and is required.

Optional parameters can be specified following the key:

=for :list
* dynamo_db_client - Directly provide a Amazon::DynamoDB object, instead of trying to build one using the class' configuration.
* inject - supply additional arguments to the class' new function, or override ones from the serialized data.

=head2 $class->dynamo_db_create_table([, dynamo_db_client => $client ][ ReadCapacityUnits => X, ... ])

Class method.  Wrapper for L<Amazon::DynamoDB>'s create_table method, with the table name and key already setup.

=head2 $client_class = $class->dynamo_db_client_class()

See L<"CLIENT CONFIGURATION">

=head2 $args = $class->dynamo_db_client_args()

See L<"CLIENT CONFIGURATION">

=head1 HOOKS

Following are methods that your consuming class can provide.

=head2 dynamo_db_table_name

A class method that will return the table name to use.  This method will be called if the L<"table_name"> parameter is not set.  So you could rewrite the Moose class in the L<"SYNOPSIS"> like this:

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

You can also change the actual method name via the L<"table_name_method"> parameter.

=head1 CLIENT CONFIGURATION

=head1 NOTES

=head2 format level (freeze/thaw)

Note that this role does not need you to implement a 'format' level for your object, i.e freeze/thaw.  You can add one if you want it for other purposes.

=head2 how references are stored

When communicating with the AWS serice, the Amazon::DynamoDB code is not handling arrayrefs correctly (they can be returned out-of-order) or hashrefs at all.  I've added a simple JSON level when encountering references - it should work seamlessly in your Perl code, but if you look up the data directly in DynamoDB you'll see complex data structures stored as JSON strings.

I'm hoping to get this fixed.

=head1 BUGS

See L<"how references are stored">.

=head1 AUTHOR

Steve Caldwell E<lt>scaldwell@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2015- Steve Caldwell

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=for :list
* L<MooseX::Storage>
* L<Amazon's DynamoDB Homepage|http://aws.amazon.com/dynamodb/>
* L<Amazon::DynamoDB> - Perl DynamoDB client.
* L<AWS::CLI::Config> - how configuration is done by default.
=cut
