requires 'perl', '5.014';

requires 'Amazon::DynamoDB';
requires 'Module::Runtime';
requires 'MooseX::Role::Parameterized';
requires 'namespace::autoclean';

on test => sub {
    requires 'Clone';
    requires 'Future';
    requires 'Moose';
    requires 'MooseX::ClassAttribute';
    requires 'MooseX::Storage';
    requires 'Kavorka';
    requires 'Test::More', '0.96';
    requires 'Type::Registry';
};
