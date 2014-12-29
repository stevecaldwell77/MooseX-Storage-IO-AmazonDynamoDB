package MooseX::Storage::IO::AmazonDynamoDB;

use strict;
use 5.014;
our $VERSION = '0.01';

use Module::Runtime qw(use_module);
use MooseX::Role::Parameterized;

use namespace::autoclean;

parameter dynamo_db_client_class => (
    isa     => 'ClassName',
    default => 'Amazon::DynamoDb',
);

role {
    my $p = shift;

    requires 'pack';
    requires 'unpack';

    method load => sub {
        my ( $class, %args ) = @_;
        # TBD: validate args.

        my $client = $class->_dynamo_db_client(%{$args{dynamo_db} || {}});

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
        # TBD: validate args.

        my $client = $self->_dynamo_db_client(%{$args{dynamo_db} || {}});

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

    method _dynamo_db_client => sub {
        my ( $class, %args ) = @_;
        # TBD: validate args.

        if (%args) {
            my $args = $class->_dynamo_db_client_args(%args);
            my $client_class = $p->dynamo_db_client_class;
            use_module $client_class;
            return $client_class->new(%$args);
        }

        # TBD: check if initialized with dynamo_db_client_method,
        #      if so return by calling that.
        die 'tbd';
    };

    method _dynamo_db_client_args => sub {
        my ( $class, %args ) = @_;

        # TBD: check class stuff for config defaults

        return \%args,
    }
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
