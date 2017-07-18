requires 'perl', '5.014';

requires 'Data::Dumper';
requires 'JSON::MaybeXS';
requires 'Moose';
requires 'MooseX::Role::Parameterized';
requires 'MooseX::Storage';
requires 'Paws';
requires 'PawsX::DynamoDB::DocumentClient';
requires 'Type::Tiny';
requires 'namespace::autoclean';

on test => sub {
    requires 'Test::DescribeMe';
    requires 'Test::Most';
    requires 'Test::Pod';
    requires 'Test::Warnings';
    requires 'UUID::Tiny';
};

on develop => sub {
    requires 'Dist::Milla';
};
