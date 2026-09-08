{ lib }:
let
  policyFor = import ./policy.nix { inherit lib; };
  valid = {
    bucket = "onix-drift";
    account = "brittonr";
    prefix = "drift/v1";
  };
  policy = policyFor valid;
  statement = builtins.head policy.Statement;
  rejected =
    overrides: !(builtins.tryEval (builtins.deepSeq (policyFor (valid // overrides)) true)).success;
in
assert policy.Version == "2012-10-17";
assert builtins.length policy.Statement == 1;
assert
  statement.Action == [
    "s3:GetObject"
    "s3:PutObject"
  ];
assert
  statement.Resource == [
    "arn:aws:s3:::onix-drift/drift/v1/users/brittonr/state.json"
    "arn:aws:s3:::onix-drift/drift/v1/users/brittonr/blobs/*"
  ];
assert rejected { account = "*"; };
assert rejected { account = "../other"; };
assert rejected { prefix = "drift//v1"; };
assert rejected { prefix = "drift/*"; };
assert rejected { bucket = ""; };
true
