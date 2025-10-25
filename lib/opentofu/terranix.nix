# Terranix Module Library - Enhanced terranix integration for clan services
# Imports from organized terranix modules for better maintainability
{ lib, pkgs }:

# Import the organized terranix modules
import ./terranix { inherit lib pkgs; }
