package MooseX::Storage::IO::AmazonDynamoDB;

use strict;
use 5.014;
our $VERSION = '0.01';

use Amazon::DynamoDB;
use AWS::CLI::Config;
use Module::Runtime qw(use_module);
use MooseX::Role::Parameterized;
use MooseX::Storage;
use Types::Standard qw(Str HashRef HasMethods);
use namespace::autoclean;

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
        return {
            access_key => AWS::CLI::Config::access_key_id,
            secret_key => AWS::CLI::Config::secret_access_key,
            host       => "dynamodb.$region.amazonaws.com",
            ssl        => 1,
        };
    };

    method load => sub {
        my ( $class, %args ) = @_;
        my $client = $args{dynamo_db_client} || $build_client->($class);

        # TBD: validate table_name, or get from class
        # TBD: validate key
        # TBD: handle failures

        my $get = $client->get_item(
            sub {
                my $data = shift;
                return $class->unpack({
                    %$data,
                    %{ $args{inject} || {} },
                });
            },
            TableName => $args{table_name},
            Key       => $args{key},
        );
        return $get->get();
    };

    method store => sub {
        my ( $self, %args ) = @_;
        my $client = $args{dynamo_db_client} || $self->$client_attr;

        # TBD: validate table_name, or get from obj/class.
        # TBD: validate key, or get from obj
        # TBD: handle failures

        my $put = $client->put_item(
            TableName => $args{table_name},
            Item => {
                %{ $args{key} },
                %{ $self->pack },
            },
        );
        return $put->get();
    };
};

1;
__END__

=encoding utf-8

=head1 NAME

MooseX::Storage::IO::AmazonDynamoDB - Blah blah blah

=head1 SYNOPSIS

  use MooseX::Storage::IO::AmazonDynamoDB;

=head1 DESCRIPTION

MooseX::Storage::IO::AmazonDynamoDB is

=head1 AUTHOR

Steve Caldwell E<lt>scaldwell@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2014- Steve Caldwell

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
