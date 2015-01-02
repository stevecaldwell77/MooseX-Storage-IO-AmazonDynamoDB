requires 'perl', '5.014';

requires 'AWS::CLI::Config';
requires 'Amazon::DynamoDB';
requires 'IO::Socket::SSL';
requires 'JSON::MaybeXS';
requires 'Module::Runtime';
requires 'Moose';
requires 'MooseX::Role::Parameterized';
requires 'MooseX::Storage';
requires 'Type::Tiny';
requires 'namespace::autoclean';

on test => sub {
    requires 'Clone';
    requires 'Future';
    requires 'Kavorka';
    requires 'MooseX::ClassAttribute';
    requires 'Test::Most';
};

on build => sub {
    requires 'Dist::Milla';
};
