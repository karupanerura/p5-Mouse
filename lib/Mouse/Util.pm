#!/usr/bin/env perl
package Mouse::Util;
use strict;
use warnings;
use base 'Exporter';

our %dependencies = (
    'Scalar::Util' => {
        'blessed' => do {
            do {
                no strict 'refs';
                *UNIVERSAL::a_sub_not_likely_to_be_here = sub {
                    my $ref = ref($_[0]);

                    # deviation from Scalar::Util
                    # XS returns undef, PP returns GLOB.
                    # let's make that more consistent by having PP return
                    # undef if it's a GLOB. :/

                    # \*STDOUT would be allowed as an object in PP blessed
                    # but not XS
                    return $ref eq 'GLOB' ? undef : $ref;
                };
            };

            sub {
                local($@, $SIG{__DIE__}, $SIG{__WARN__});
                length(ref($_[0]))
                    ? eval { $_[0]->a_sub_not_likely_to_be_here }
                    : undef;
            },
        },
        'looks_like_number' => sub {
            local $_ = shift;

            # checks from perlfaq4
            return 0 if !defined($_) or ref($_);
            return 1 if (/^[+-]?\d+$/); # is a +/- integer
            return 1 if (/^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/); # a C float
            return 1 if ($] >= 5.008 and /^(Inf(inity)?|NaN)$/i) or ($] >= 5.006001 and /^Inf$/i);

            0;
        },
        'reftype' => sub {
            local($@, $SIG{__DIE__}, $SIG{__WARN__});
            my $r = shift;
            my $t;

            length($t = ref($r)) or return undef;

            # This eval will fail if the reference is not blessed
            eval { $r->a_sub_not_likely_to_be_here; 1 }
            ? do {
                $t = eval {
                    # we have a GLOB or an IO. Stringify a GLOB gives it's name
                    my $q = *$r;
                    $q =~ /^\*/ ? "GLOB" : "IO";
                }
                or do {
                    # OK, if we don't have a GLOB what parts of
                    # a glob will it populate.
                    # NOTE: A glob always has a SCALAR
                    local *glob = $r;
                    defined *glob{ARRAY} && "ARRAY"
                        or defined *glob{HASH} && "HASH"
                        or defined *glob{CODE} && "CODE"
                        or length(ref(${$r})) ? "REF" : "SCALAR";
                }
            }
            : $t
        },
        'openhandle' => sub {
            my $fh = shift;
            my $rt = reftype($fh) || '';

            return defined(fileno($fh)) ? $fh : undef
                if $rt eq 'IO';

            if (reftype(\$fh) eq 'GLOB') { # handle  openhandle(*DATA)
                $fh = \(my $tmp=$fh);
            }
            elsif ($rt ne 'GLOB') {
                return undef;
            }

            (tied(*$fh) or defined(fileno($fh)))
                ? $fh : undef;
        },
    },
    'MRO::Compat' => {
        'get_linear_isa' => {
            loaded     => \&mro::get_linear_isa,
            not_loaded => do {
                # this recurses so it isn't pretty
                my $code;
                $code = sub {
                    no strict 'refs';

                    my $classname = shift;

                    my @lin = ($classname);
                    my %stored;
                    foreach my $parent (@{"$classname\::ISA"}) {
                        my $plin = $code->($parent);
                        foreach (@$plin) {
                            next if exists $stored{$_};
                            push(@lin, $_);
                            $stored{$_} = 1;
                        }
                    }
                    return \@lin;
                }
            },
        },
    },
);

our @EXPORT_OK = map { keys %$_ } values %dependencies;

for my $module_name (keys %dependencies) {
    (my $file = "$module_name.pm") =~ s{::}{/}g;

    my $loaded = do {
        local $SIG{__DIE__} = 'DEFAULT';
        eval "require '$file'; 1";
    };

    for my $method_name (keys %{ $dependencies{ $module_name } }) {
        my $producer = $dependencies{$module_name}{$method_name};
        my $implementation;

        if (ref($producer) eq 'HASH') {
            $implementation = $loaded
                            ? $producer->{loaded}
                            : $producer->{not_loaded};
        }
        else {
            $implementation = $loaded
                            ? $module_name->can($method_name)
                            : $producer;
        }

        no strict 'refs';
        *{ __PACKAGE__ . '::' . $method_name } = $implementation;
    }
}

push @EXPORT_OK, qw(weaken);
sub weaken {
    require Scalar::Util;
    goto \&Scalar::Util::weaken;
}

1;

