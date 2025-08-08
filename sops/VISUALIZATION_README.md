# SOPS Hierarchy Visualization Tools

This directory contains tools to visualize the SOPS access control hierarchy showing relationships between users, groups, machines, and secrets.

## Available Scripts

### 1. Simple Visualizer (No Dependencies)
`visualize_sops_simple.py` - Works out of the box with Python 3

```bash
# Show hierarchy tree
./visualize_sops_simple.py

# Show access matrix
./visualize_sops_simple.py --matrix

# Generate Graphviz DOT file
./visualize_sops_simple.py --dot

# Show all visualizations
./visualize_sops_simple.py --all
```

### 2. Rich Visualizer (Enhanced TUI)
`visualize_sops_hierarchy.py` - Requires `rich` and optionally `graphviz` packages

```bash
# Install dependencies
pip install -r requirements.txt

# Show enhanced tree view
./visualize_sops_hierarchy.py

# Show access matrix table
./visualize_sops_hierarchy.py --table

# Generate graph image (PNG/SVG/PDF)
./visualize_sops_hierarchy.py --graph

# Show all visualizations
./visualize_sops_hierarchy.py --all
```

## Output Examples

### Hierarchy Tree
Shows the complete structure with:
- Users and their group memberships
- Machines and their group associations
- Groups with their members
- Secrets with access permissions

### Access Matrix
Displays a table showing which users and machines have access to each secret.

### Graphviz Output
Creates visual graph diagrams showing all relationships:
- Convert DOT to PNG: `dot -Tpng sops_hierarchy.dot -o sops_hierarchy.png`
- Convert DOT to SVG: `dot -Tsvg sops_hierarchy.dot -o sops_hierarchy.svg`

## Key Insights from Current Structure

1. **Admin Users**: alex and brittonr are both admins with broad access
2. **Machine Groups**: 
   - cert-blr_dev: britton-desktop, britton-fw
   - cert-onix_computer: gmk1, gmk2, gmk3
3. **Special Access**: britton-fw machine has access to gmk1-age.key (likely for management)
4. **Access Patterns**: Most secrets are user-specific, with gmk* secrets shared between admins