# MicroVM Secret Passing Flowchart

## Complete Secret Flow Diagram

```mermaid
graph TB
    %% Build Time - Secret Generation
    subgraph "Build Time - Host Configuration"
        A[Clan Vars Generator<br/>test-vm-secrets] --> B[OpenSSL Secret Generation<br/>api-key, db-password, jwt-secret]
        B --> C[SOPS Encryption<br/>vars/per-machine/test-vm/]
    end

    %% Runtime - Host Side
    subgraph "Runtime - Host (britton-desktop)"
        D[SOPS Decryption<br/>/run/secrets/vars/test-vm-secrets/] --> E[SystemD LoadCredential<br/>microvm@test-vm.service]
        E --> F[Credential Files<br/>$CREDENTIALS_DIRECTORY/<br/>host-api-key, host-db-password, host-jwt-secret]
    end

    %% MicroVM Framework
    subgraph "MicroVM.nix Framework"
        G[credentialFiles Declaration<br/>microvm.credentialFiles] --> H[Modified cloud-hypervisor Runner<br/>lib/runners/cloud-hypervisor.nix]
        H --> I[Runtime OEM String Generation<br/>io.systemd.credential:HOST-API-KEY=value]
        I --> J[Platform Option Merging<br/>Static + Runtime OEM Strings]
    end

    %% Hypervisor Launch
    subgraph "Hypervisor Launch"
        K[cloud-hypervisor Command<br/>--platform oem_strings=[...]] --> L[SMBIOS Type 11 OEM Strings<br/>Embedded in Virtual Hardware]
    end

    %% Guest Side
    subgraph "Guest OS (test-vm)"
        M[SystemD Boot Process<br/>Reads SMBIOS OEM Strings] --> N[SystemD Credential API<br/>Parses io.systemd.credential:*]
        N --> O[Service LoadCredential<br/>Maps HOST-API-KEY to api-key]
        O --> P[Guest Service Access<br/>$CREDENTIALS_DIRECTORY/api-key]
    end

    %% Flow connections
    C --> D
    F --> H
    G --> H
    J --> K
    L --> M

    %% Additional connections for clarity
    A -.-> G

    %% Styling
    classDef buildTime fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef runtime fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef framework fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    classDef hypervisor fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef guest fill:#fce4ec,stroke:#880e4f,stroke-width:2px

    class A,B,C buildTime
    class D,E,F runtime
    class G,H,I,J framework
    class K,L hypervisor
    class M,N,O,P guest
```

## Detailed Step-by-Step Flow

```mermaid
sequenceDiagram
    participant CG as Clan Vars Generator
    participant SOPS as SOPS Encryption
    participant SD as SystemD Service
    participant MVM as MicroVM Runner
    participant CH as Cloud Hypervisor
    participant GM as Guest Machine
    participant GS as Guest Service

    %% Build Time
    Note over CG,SOPS: Build Time Secret Generation
    CG->>SOPS: Generate secrets (OpenSSL)
    SOPS->>SOPS: Encrypt with age keys
    SOPS->>SOPS: Store in vars/per-machine/test-vm/

    %% Runtime Host
    Note over SD,MVM: Runtime Host Secret Handling
    SD->>SD: Decrypt SOPS secrets to /run/secrets/
    SD->>SD: LoadCredential into $CREDENTIALS_DIRECTORY
    SD->>MVM: Start microvm@test-vm service

    %% MicroVM Framework Processing
    Note over MVM,CH: MicroVM Framework Processing
    MVM->>MVM: Read credentialFiles config
    MVM->>MVM: Read systemd credentials from $CREDENTIALS_DIRECTORY
    MVM->>MVM: Generate runtime OEM strings
    MVM->>MVM: Merge with static platform options
    MVM->>CH: Launch with --platform oem_strings=[...]

    %% Hypervisor to Guest
    Note over CH,GS: Guest Secret Access
    CH->>GM: Embed OEM strings in SMBIOS Type 11
    GM->>GM: SystemD reads SMBIOS at boot
    GM->>GM: Parse io.systemd.credential:* entries
    GM->>GS: LoadCredential maps to service credentials
    GS->>GS: Access via $CREDENTIALS_DIRECTORY
```

## Security Boundary Analysis

```mermaid
graph LR
    subgraph "Security Zone 1: Encrypted Storage"
        A[SOPS Encrypted Files<br/>vars/per-machine/test-vm/]
    end

    subgraph "Security Zone 2: Host Runtime"
        B[Decrypted Files<br/>/run/secrets/]
        C[SystemD Credentials<br/>$CREDENTIALS_DIRECTORY]
    end

    subgraph "Security Zone 3: Process Memory"
        D[MicroVM Runner<br/>Environment Variables]
        E[cloud-hypervisor<br/>Command Line Args]
    end

    subgraph "Security Zone 4: Virtual Hardware"
        F[SMBIOS OEM Strings<br/>Type 11 Entries]
    end

    subgraph "Security Zone 5: Guest Runtime"
        G[Guest SystemD<br/>Credential API]
        H[Guest Service<br/>$CREDENTIALS_DIRECTORY]
    end

    A -->|SOPS Decryption| B
    B -->|LoadCredential| C
    C -->|Runtime Reading| D
    D -->|Platform Args| E
    E -->|Hardware Embedding| F
    F -->|Boot Process| G
    G -->|Service Mapping| H

    %% Security annotations
    A -.->|Age Encrypted| A
    B -.->|Root Only Access| B
    C -.->|Service Isolation| C
    D -.->|Process Memory| D
    E -.->|Brief CLI Exposure| E
    F -.->|Hardware Isolation| F
    G -.->|SystemD Security| G
    H -.->|Process Isolation| H
```

## Component Interaction Diagram

```mermaid
graph TD
    %% Host Components
    subgraph "Host System (britton-desktop)"
        H1[Clan Vars<br/>test-vm-secrets]
        H2[SOPS-nix Module<br/>Decryption]
        H3[SystemD Service<br/>microvm@test-vm]
        H4[MicroVM Configuration<br/>credentialFiles]
    end

    %% MicroVM Framework
    subgraph "MicroVM.nix Framework"
        F1[cloud-hypervisor.nix<br/>Modified Runner]
        F2[runner.nix<br/>Launch Script]
        F3[Platform Options<br/>OEM String Merger]
    end

    %% Guest Components
    subgraph "Guest System (test-vm)"
        G1[SystemD Init<br/>SMBIOS Reader]
        G2[Credential API<br/>SystemD]
        G3[Demo Service<br/>LoadCredential]
    end

    %% Data Flow
    H1 --> H2
    H2 --> H3
    H3 --> F1
    H4 --> F1
    F1 --> F3
    F3 --> F2
    F2 --> G1
    G1 --> G2
    G2 --> G3

    %% Configuration Flow
    H4 -.-> F1

    %% Legend
    H1 -.->|Generated Secrets| H1
    F1 -.->|Runtime Processing| F1
    G2 -.->|Credential Access| G2
```

## Data Transformation Pipeline

```mermaid
graph LR
    subgraph "Data Transformations"
        A["Raw Secret<br/>(OpenSSL base64)"]
        B["SOPS Encrypted<br/>(JSON + age)"]
        C["Decrypted File<br/>(/run/secrets/)"]
        D["SystemD Credential<br/>($CREDENTIALS_DIRECTORY)"]
        E["OEM String<br/>(io.systemd.credential:NAME=value)"]
        F["SMBIOS Entry<br/>(Type 11 Hardware)"]
        G["SystemD Credential<br/>(Guest API)"]
        H["Service Access<br/>($CREDENTIALS_DIRECTORY)"]
    end

    A -->|SOPS Encrypt| B
    B -->|Runtime Decrypt| C
    C -->|LoadCredential| D
    D -->|Runtime Read| E
    E -->|Hardware Embed| F
    F -->|Boot Parse| G
    G -->|Service Map| H

    %% Format annotations
    A -.->|"API_KEY=AbCdEf..."| A
    B -.->|"{'data': 'encrypted...'}"| B
    C -.->|"/run/secrets/vars/..."| C
    D -.->|"/run/credentials/..."| D
    E -.->|"io.systemd.credential:HOST-API-KEY=..."| E
    F -.->|"SMBIOS Type 11 OEM"| F
    G -.->|"SystemD Credential API"| G
    H -.->|"Guest Service Access"| H
```

## Key Technical Features

### 1. **Dual OEM String Support**
- **Static OEM Strings**: Build-time configuration (ENVIRONMENT=test, CLUSTER=britton-desktop)
- **Runtime OEM Strings**: Dynamic secret injection (HOST-API-KEY=..., HOST-DB-PASSWORD=...)

### 2. **Credential Name Mapping**
```
Host Side:          MicroVM Config:     OEM String:           Guest Mapping:
host-api-key   →    credentialFiles  →  HOST-API-KEY=value →  api-key
host-db-password →  credentialFiles  →  HOST-DB-PASSWORD=.. → db-password
host-jwt-secret  →  credentialFiles  →  HOST-JWT-SECRET=..  → jwt-secret
```

### 3. **Security Isolation Layers**
- **SOPS Encryption**: Age-encrypted at rest
- **SystemD Credentials**: Process isolation on host
- **SMBIOS Hardware**: Hypervisor-level embedding
- **Guest SystemD**: Service-level credential isolation

### 4. **Error Handling & Validation**
- **Missing Credentials**: Graceful handling of absent credential files
- **Format Validation**: Proper OEM string format enforcement
- **Service Hardening**: Comprehensive systemd security restrictions

This flowchart demonstrates the sophisticated multi-layer security architecture that enables secure, declarative secret passing from clan vars to microVM guests while maintaining strong isolation boundaries at each stage.