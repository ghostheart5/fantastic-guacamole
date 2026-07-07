<style>
a {
    text-decoration: none;
    color: #464feb;
}
tr th, tr td {
    border: 1px solid #e6e6e6;
}
tr th {
    background-color: #f5f5f5;
}
</style>

## How to know if each file is full vs just a placeholder

Use this inspection checklist.

### Entity file checklist

A full entity file should answer:
- Does it have a stable ID or identity?
- Does it contain only domain data, not UI widget state?
- Are required fields non-null where appropriate?
- Are statuses/enums/value objects typed?
- Does it avoid Flutter/Firebase/Hive/Supabase imports?
- Does it represent relationships intentionally?
- Does it include copyWith/equality if the app state needs immutable updates?
- Does it avoid raw JSON/storage logic unless you intentionally allow that in domain?

### Interface file checklist

A full repository interface should answer:
- Can every use case call a method on this interface?
- Do method names match domain language, not storage language?
- Does it return domain entities, not DTOs or Hive records?
- Does it expose failure/result types consistently?
- Does it avoid implementation details like box names, tables, URLs, SDK clients?

### Use-case file checklist

A full use case should answer:
- Does it do exactly one business operation?
- Does it depend on an interface, not a concrete data repository?
- Does it apply relevant policy/validation?
- Does it return a domain entity/result, not UI state?
- Can I unit-test it with a fake repository?

## Practical completeness test by feature

For each feature:
1. Entity exists?
2. Interface exists?
3. Use cases cover user actions?
4. Data repository implements interface?
5. Provider wires implementation?
6. UI calls provider/controller, not repository?
7. Unit tests exist for entity/policy/usecase?

## What is currently enforced automatically

The architecture checker now enforces these lightweight heuristics:
- domain entities cannot import Flutter/Firebase/Hive/Supabase packages
- domain interfaces cannot depend on data/system layers
- domain interface files must declare an abstract `I*Repository`
- domain usecases cannot import concrete data repositories
- domain usecases cannot import Flutter or Riverpod

Anything beyond that still needs engineering judgment. The checklist is the source of truth; the script only catches the most obvious placeholder patterns.
