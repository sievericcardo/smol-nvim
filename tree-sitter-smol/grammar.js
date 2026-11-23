/**
 * Tree-sitter grammar for SMOL (Sensor Modelling and Ontology Language).
 *
 * The grammar follows the PEG grammar shipped with lockpick
 * (`crates/smol-parser/src/smol.pest`) and is deliberately tolerant: it is
 * meant for editor highlighting, folding, text objects and structural
 * navigation, not for rejecting programs. Semantic validation is the job of
 * `lockpick-lsp`.
 *
 * Notable design choices:
 *   - `identifier` is a lowercase/underscore name (variables, methods, fields)
 *     and `type_identifier` is an uppercase name (classes, ontology types).
 *     This mirrors every SMOL program in the wild and removes the classic
 *     "declaration vs. assignment" ambiguity without lookahead.
 *   - Abstract methods have no `end` in SMOL; concrete methods always do.
 *     They are separate productions so that a method body can never swallow
 *     the next method declaration.
 *   - JML-style contracts (`/*@ requires ... @*\/`) live inside block
 *     comments and are highlighted as documentation comments.
 */

const PREC = {
  or: 1,
  and: 2,
  equality: 3,
  comparison: 4,
  additive: 5,
  multiplicative: 6,
  unary: 7,
  call: 8,
  field: 9,
};

const commaSep1 = (rule) => seq(rule, repeat(seq(',', rule)));

/** `access`, `construct`, ... are reserved words that take an argument list. */
const builtin = ($, name) =>
  seq(name, field('arguments', $.argument_list));

module.exports = grammar({
  name: 'smol',

  extras: ($) => [/\s+/, $.line_comment, $.block_comment],

  word: ($) => $.identifier,

  rules: {
    source_file: ($) => repeat($._top_level),

    _top_level: ($) => choice($.class_declaration, $.main_declaration),

    // ── Classes ────────────────────────────────────────────────────────── //

    class_declaration: ($) =>
      seq(
        optional('abstract'),
        optional('hidden'),
        'class',
        field('name', $.type_identifier),
        optional($.type_parameters),
        optional(seq('extends', field('superclass', $.type))),
        field('parameters', $.field_parameter_list),
        optional(field('body', $.class_body)),
        'end',
      ),

    class_body: ($) => repeat1($._class_member),

    type_parameters: ($) => seq('<', commaSep1($.type_identifier), '>'),

    field_parameter_list: ($) =>
      seq('(', optional(commaSep1($.field_parameter)), ')'),

    field_parameter: ($) =>
      seq(
        optional(choice('hidden', 'domain', 'context')),
        field('type', $.type),
        field('name', $.identifier),
      ),

    _class_member: ($) =>
      choice(
        $.abstract_method_declaration,
        $.member_declaration,
        $.models_clause,
        $.classifies_clause,
        $.retrieves_clause,
      ),

    /**
     * A field initializer (`Int count = 0;`) and a concrete method share the
     * `[modifiers] Type name` prefix; keeping them in one production keeps the
     * grammar LR(1).
     */
    member_declaration: ($) =>
      seq(
        repeat(choice('hidden', 'domain', 'context', 'rule', 'override')),
        field('type', $.type),
        field('name', $.identifier),
        choice(
          seq('=', field('value', $._expression), ';'),
          seq(
            field('parameters', $.parameter_list),
            optional($.adapts_clause),
            optional(field('body', $.block)),
            'end',
          ),
        ),
      ),

    abstract_method_declaration: ($) =>
      seq(
        'abstract',
        repeat(choice('rule', 'domain', 'override')),
        field('type', $.type),
        field('name', $.identifier),
        field('parameters', $.parameter_list),
        optional($.adapts_clause),
      ),

    adapts_clause: ($) => seq('adapts', commaSep1($.type_identifier)),

    parameter_list: ($) => seq('(', optional(commaSep1($.parameter)), ')'),

    parameter: ($) => seq(field('type', $.type), field('name', $.identifier)),

    models_clause: ($) =>
      seq(
        'links',
        optional(seq('(', field('guard', $._expression), ')')),
        field('fragment', $.string),
        ';',
      ),

    classifies_clause: ($) => seq('classifies', $.string, ';'),

    retrieves_clause: ($) => seq('retrieves', $.string, ';'),

    main_declaration: ($) =>
      seq('main', optional(field('body', $.block)), 'end'),

    // ── Types ──────────────────────────────────────────────────────────── //

    type: ($) =>
      choice(
        $.generic_type,
        $.fmo_type,
        $.primitive_type,
        $.type_identifier,
      ),

    generic_type: ($) =>
      seq(
        field('name', choice($.primitive_type, $.type_identifier)),
        '<',
        commaSep1($.type),
        '>',
      ),

    fmo_type: ($) =>
      seq('FMO', '[', optional(commaSep1($.fmo_port)), ']'),

    fmo_port: ($) =>
      seq(choice('in', 'out'), field('type', $.type), field('name', $.identifier)),

    primitive_type: ($) =>
      choice(
        'Int',
        'Double',
        'String',
        'Boolean',
        'Bool',
        'Unit',
        'List',
        'ExplList',
        'Nullable',
      ),

    // ── Statements ─────────────────────────────────────────────────────── //

    block: ($) => repeat1($._statement),

    _statement: ($) =>
      choice(
        $.skip_statement,
        $.breakpoint_statement,
        $.return_statement,
        $.print_statement,
        $.destroy_statement,
        $.if_statement,
        $.while_statement,
        $.declaration_statement,
        $.assignment_statement,
        $.expression_statement,
      ),

    skip_statement: ($) => seq('skip', ';'),

    breakpoint_statement: ($) => seq('breakpoint', ';'),

    return_statement: ($) => seq('return', optional($._expression), ';'),

    print_statement: ($) => seq('print', $.argument_list, ';'),

    destroy_statement: ($) => seq('destroy', $.argument_list, ';'),

    if_statement: ($) =>
      seq(
        'if',
        field('condition', $._expression),
        'then',
        field('consequence', $.block),
        optional(seq('else', field('alternative', $.block))),
        'end',
      ),

    while_statement: ($) =>
      seq(
        'while',
        field('condition', $._expression),
        optional(seq('decreases', field('variant', $._expression))),
        'do',
        field('body', $.block),
        'end',
      ),

    declaration_statement: ($) =>
      seq(
        field('type', $.type),
        field('name', $.identifier),
        '=',
        field('value', $._expression),
        optional(seq('links', field('description', $._expression))),
        ';',
      ),

    assignment_statement: ($) =>
      seq(
        field('left', $._expression),
        '=',
        field('right', $._expression),
        optional(seq('links', field('description', $._expression))),
        ';',
      ),

    expression_statement: ($) => seq($._expression, ';'),

    // ── Expressions ────────────────────────────────────────────────────── //

    _expression: ($) =>
      choice(
        $.binary_expression,
        $.unary_expression,
        $.field_expression,
        $.method_invocation,
        $.call_expression,
        $.new_expression,
        $.access_expression,
        $.construct_expression,
        $.classify_expression,
        $.adapt_expression,
        $.member_expression,
        $.validate_expression,
        $.simulate_expression,
        $.super_expression,
        $.sparql_mode,
        $.influxdb_mode,
        $.parenthesized_expression,
        $.this_expression,
        $.identifier,
        $.number,
        $.string,
        $.boolean,
        $.null_literal,
        $.unit_literal,
      ),

    binary_expression: ($) => {
      const table = [
        ['||', PREC.or],
        ['|', PREC.or],
        ['&&', PREC.and],
        ['&', PREC.and],
        ['==', PREC.equality],
        ['!=', PREC.equality],
        ['<=', PREC.comparison],
        ['>=', PREC.comparison],
        ['<', PREC.comparison],
        ['>', PREC.comparison],
        ['++', PREC.additive],
        ['+', PREC.additive],
        ['-', PREC.additive],
        ['*', PREC.multiplicative],
        ['/', PREC.multiplicative],
        ['%', PREC.multiplicative],
      ];

      return choice(
        ...table.map(([operator, precedence]) =>
          prec.left(
            precedence,
            seq(
              field('left', $._expression),
              operator,
              field('right', $._expression),
            ),
          ),
        ),
      );
    },

    unary_expression: ($) =>
      prec(
        PREC.unary,
        seq(choice('!', '-'), field('argument', $._expression)),
      ),

    field_expression: ($) =>
      prec.left(
        PREC.field,
        seq(
          field('receiver', $._expression),
          '.',
          field('field', $.identifier),
        ),
      ),

    method_invocation: ($) =>
      prec.left(
        PREC.call,
        seq(
          field('receiver', $._expression),
          '.',
          field('name', $.identifier),
          field('arguments', $.argument_list),
        ),
      ),

    call_expression: ($) =>
      prec(
        PREC.call,
        seq(
          field('function', $.identifier),
          field('arguments', $.argument_list),
        ),
      ),

    new_expression: ($) =>
      prec(
        PREC.call,
        seq('new', field('type', $.type), field('arguments', $.argument_list)),
      ),

    access_expression: ($) => builtin($, 'access'),
    construct_expression: ($) => builtin($, 'construct'),
    classify_expression: ($) => builtin($, 'classify'),
    adapt_expression: ($) => builtin($, 'adapt'),
    member_expression: ($) => builtin($, 'member'),
    validate_expression: ($) => builtin($, 'validate'),
    simulate_expression: ($) =>
      seq(
        'simulate',
        '(',
        field('model', $.string),
        optional(seq(',', commaSep1($.named_argument))),
        ')',
      ),

    named_argument: ($) =>
      seq(field('name', $.identifier), '=', field('value', $._expression)),
    super_expression: ($) => builtin($, 'super'),

    influxdb_mode: ($) => builtin($, 'INFLUXDB'),
    sparql_mode: ($) => seq('SPARQL'),

    argument_list: ($) => seq('(', optional(commaSep1($._expression)), ')'),

    parenthesized_expression: ($) => seq('(', $._expression, ')'),

    this_expression: ($) => seq('this'),

    null_literal: ($) => seq('null'),

    unit_literal: ($) => seq('unit'),

    boolean: ($) => choice('True', 'False', 'true', 'false'),

    number: ($) => choice($.float, $.integer),

    integer: ($) => token(/[0-9]+/),

    float: ($) =>
      token(/([0-9]+\.[0-9]*|\.[0-9]+)([eE][+-]?[0-9]+)?/),

    string: ($) =>
      seq(
        '"',
        repeat(choice($.escape_sequence, /[^"\\]+/)),
        '"',
      ),

    escape_sequence: ($) => token.immediate(seq('\\', /./)),

    // ── Lexical ────────────────────────────────────────────────────────── //

    // Lower-case names: variables, methods, fields.
    identifier: ($) => token(prec(-1, /[a-z_][A-Za-z0-9_]*/)),

    // Upper-case names: classes, ontology-generated types.
    type_identifier: ($) => token(prec(-1, /[A-Z][A-Za-z0-9_]*/)),

    line_comment: ($) => token(seq('//', /[^\n]*/)),

    block_comment: ($) =>
      token(
        seq(
          '/*',
          repeat(choice(/[^*]/, /\*+[^*/]/)),
          /\*+\//,
        ),
      ),
  },
});
