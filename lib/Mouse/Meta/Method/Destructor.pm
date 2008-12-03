package Mouse::Meta::Method::Destructor;
use strict;
use warnings;

sub generate_destructor_method_inline {
    my ($class, $meta) = @_;

    my $demolishall = do {
        if ($meta->name->can('DEMOLISH')) {
            my @code = ();
            no strict 'refs';
            for my $klass ($meta->linearized_isa) {
                if (*{$klass . '::DEMOLISH'}{CODE}) {
                    push @code, "${klass}::DEMOLISH(\$self);";
                }
            }
            join "\n", @code;
        } else {
            ''; # no demolish =)
        }
    };

    my $code = <<"...";
    sub {
        my \$self = shift;
        $demolishall;
    }
...
    warn $code if $ENV{DEBUG};

    local $@;
    my $res = eval $code;
    die $@ if $@;
    $res;
}

1;
