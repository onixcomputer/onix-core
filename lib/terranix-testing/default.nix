{
  # Performance tests require appropriate terraform context
  # Import as a function to avoid immediate evaluation
  performanceTests = ./performance-tests/test.nix;
}
