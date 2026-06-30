# Gesture configuration — source of truth.
#
# Defines Niri gesture tuning and lisgd touchscreen bindings
# for touchpad and touchscreen input.
#
# Consumed by: gestures.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/gestures.ncl
#   3. Commit .ncl
let Positive =
  std.contract.from_validator (match {
    value if std.is_number value && value > 0 => 'Ok,
    _ => 'Error { message = "must be a positive number" },
  }
  )
in

let NonNeg =
  std.contract.from_validator (match {
    value if std.is_number value && value >= 0 => 'Ok,
    _ => 'Error { message = "must be a non-negative number" },
  }
  )
in

let GestureDirection =
  std.contract.from_validator (match {
    "LR" => 'Ok,
    "RL" => 'Ok,
    "DU" => 'Ok,
    "UD" => 'Ok,
    _ => 'Error { message = "must be one of: LR, RL, DU, UD" },
  }
  )
in

let GestureEdge =
  std.contract.from_validator (match {
    "L" => 'Ok,
    "R" => 'Ok,
    "T" => 'Ok,
    "B" => 'Ok,
    "*" => 'Ok,
    "N" => 'Ok,
    _ => 'Error { message = "must be one of: L, R, T, B, *, N" },
  }
  )
in

let GestureDistance =
  std.contract.from_validator (match {
    "S" => 'Ok,
    "M" => 'Ok,
    "L" => 'Ok,
    "*" => 'Ok,
    _ => 'Error { message = "must be one of: S, M, L, *" },
  }
  )
in

let GestureActMode =
  std.contract.from_validator (match {
    "R" => 'Ok,
    "P" => 'Ok,
    _ => 'Error { message = "must be one of: R, P" },
  }
  )
in

let NiriAction =
  std.contract.from_validator (match {
    "focus-workspace-up" => 'Ok,
    "focus-workspace-down" => 'Ok,
    "toggle-overview" => 'Ok,
    _ => 'Error { message = "must be a supported niri gesture action" },
  }
  )
in

let LisgdBinding = {
  fingers | doc "Number of fingers that trigger the gesture" | Positive,
  direction | doc "Swipe direction in lisgd notation" | GestureDirection,
  edge | doc "Screen edge constraint in lisgd notation" | GestureEdge,
  distance | doc "Gesture distance threshold in lisgd notation" | GestureDistance,
  actMode | doc "Gesture activation mode in lisgd notation" | GestureActMode,
  action | doc "Niri action passed to niri msg" | NiriAction,
  label | doc "Notification label shown after the action" | String,
}
in

{
  dndEdgeScroll | doc "Drag and drop edge scroll settings" = {
    triggerWidth | doc "Edge trigger width in pixels" | Positive = 40,
    delayMs | doc "Trigger delay in milliseconds" | Positive = 150,
    maxSpeed | doc "Maximum scroll speed" | Positive = 1200,
  },
  dndEdgeWorkspaceSwitch | doc "Overview drag and drop workspace switch settings" = {
    triggerHeight | doc "Vertical edge trigger height in pixels" | Positive = 80,
    delayMs | doc "Trigger delay in milliseconds" | Positive = 150,
    maxSpeed | doc "Maximum workspace switch speed" | Positive = 1500,
  },
  lisgd | doc "Lisgd gesture daemon settings" = {
    timeout | doc "Gesture timeout in milliseconds" | Positive = 150,
    outputIndex | doc "Output device index" | NonNeg = 0,
    sessionWaitAttempts | doc "Number of session environment polls before exiting" | Positive = 60,
    startLimitBurst | doc "Systemd restart burst limit" | Positive = 3,
    startLimitIntervalSec | doc "Systemd restart limit interval in seconds" | Positive = 30,
    bindings | doc "Touchscreen gesture bindings" | Array LisgdBinding = [
      {
        fingers = 1,
        direction = "DU",
        edge = "B",
        distance = "M",
        actMode = "R",
        action = "toggle-overview",
        label = "Overview",
      },
      {
        fingers = 2,
        direction = "LR",
        edge = "L",
        distance = "M",
        actMode = "R",
        action = "focus-workspace-up",
        label = "← Prev WS",
      },
      {
        fingers = 2,
        direction = "RL",
        edge = "R",
        distance = "M",
        actMode = "R",
        action = "focus-workspace-down",
        label = "→ Next WS",
      },
      {
        fingers = 3,
        direction = "LR",
        edge = "*",
        distance = "M",
        actMode = "R",
        action = "focus-workspace-up",
        label = "← Prev WS",
      },
      {
        fingers = 3,
        direction = "RL",
        edge = "*",
        distance = "M",
        actMode = "R",
        action = "focus-workspace-down",
        label = "→ Next WS",
      },
      {
        fingers = 4,
        direction = "DU",
        edge = "*",
        distance = "M",
        actMode = "R",
        action = "toggle-overview",
        label = "Overview",
      },
      {
        fingers = 4,
        direction = "UD",
        edge = "*",
        distance = "M",
        actMode = "R",
        action = "toggle-overview",
        label = "Overview",
      },
    ],
  },
}
