unit package WebAssembly;
use WebAssembly::Sections;
use WebAssembly::Module;
use WebAssembly::Opcodes;

multi decompile(Str $code) { $code }

multi decompile(FuncType $_) {
    [~] '(', .param_types.kv.map({ "$^v \%$^k" }).join(', ') , ')',
        .return_count ?? " -> {.return_type}" !! '';
}

multi decompile(GlobalType $_) {
    "{.content_type}"
}

multi decompile(MemoryType $_) {
    "memory({ decompile .limits })";
}

multi decompile(ResizableLimits $_) {
    .flags ?? "{.initial}..{.maximum}" !! "{.initial}";
}

multi decompile(ImportSection $_) {
    for .entries {
        my $type = decompile .kind == Function
            ?? $*module.type(.type)
            !! .type;

        take "import {.module}.{.field} : $type";
    }

    take '';
}

multi decompile(ExportSection $_) {
    for .entries {
        take "export {.field}";
    }

    take '';
}

multi decompile(GlobalSection $_) {
    for .entries.kv -> $id, $_ {
        take "global \@{$id} : {.type}";
    }

    take '';
}

multi decompile(LocalEntry $_) {
    my $count = .count;
    my $first = $*locals;
    my $last = $first + $count - 1;
    take "    local {.type} \%{$count > 1 ?? $first !! $first..$last}";
    $*locals += $count;
}

multi decompile(CodeSection $_) {
    for .entries.kv -> $pos, $_ {
        my $index = .index;
        my $type = $*module.signature($pos);
        my $name = $*module.exportname(:func, $index) // "\$$index";
        my $*locals = $type.param_count;
        take "fn {$name // "\$$index"}{decompile $type} \{";
        decompile $_ for .locals;

        my @statement;
        my @code := .code;
        loop (my $i = 0; $i < @code; ++$i) {
            given @code[$i] {
                when op::get_global {
                    my $id = @code[++$i];
                    @statement.push("\@$id");
                }
                when op::i32-load {
                    my $flags = @code[++$i];
                    my $offset = @code[++$i];
                    my $address = @statement.pop;
                    $address ~= " + $offset" if $offset;
                    @statement.push("i32:{2**$flags}({$address})")
                }
                when op::set_local {
                    my $id = @code[++$i];
                    @statement.unshift("\%$id", '=');
                    take "    " ~ @statement.join(' ');
                    @statement = Empty;
                }
                when op::get_local {
                    my $id = @code[++$i];
                    @statement.push("\%$id");
                }
                when op::i32-const {
                    @statement.push(~@code[++$i]);
                }
                when op::nop {
                    take "    nop";
                }
                when op::call {
                    my $id = @code[++$i];
                    my $fn = "\$$id";
                    @statement = "$fn\({@statement.join(', ')})";
                }
                when op::return {
                    given $type.return_count {
                        when 0 {
                            take "    {@statement.shift}" while @statement;
                            take "    return";
                        }
                        when 1 {
                            take "    {@statement.shift}" while @statement > 1;
                            take "    return {@statement.shift}";
                        }
                        default {
                            die "illegal return count";
                        }
                    }
                }
                when op::end {
                    die 'unterminated statement' if @statement;
                    last;
                }
                default {
                    take "    NYI $_";
                    last;
                }
            }
        }

        take "}\n";
    }
}

my class siol is export {
    proto method decompile($) {*}

    multi method decompile(Module $_) {
        my $*module = $_;
        join "\n", gather {
            decompile($_) with .import_section;
            decompile($_) with .export_section;
            decompile($_) with .global_section;
            decompile($_) with .code_section;
        }
    }

    multi method decompile($source) {
        self.decompile(Module.load($source));
    }

    method compile(Str $code) {
        42
    }
}
