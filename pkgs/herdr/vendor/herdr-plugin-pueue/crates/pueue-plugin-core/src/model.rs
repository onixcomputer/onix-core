use std::collections::BTreeMap;

const PAIR_WINDOW_SIZE: usize = 2;

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct TaskId(u64);

impl TaskId {
    pub const fn new(value: u64) -> Self {
        Self(value)
    }

    pub const fn get(self) -> u64 {
        self.0
    }
}

impl std::fmt::Display for TaskId {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        self.0.fmt(formatter)
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PueueVersion {
    pub major: u64,
    pub minor: u64,
    pub patch: u64,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum GroupState {
    Running,
    Paused,
    Reset,
}

impl GroupState {
    pub const fn label(self) -> &'static str {
        match self {
            Self::Running => "running",
            Self::Paused => "paused",
            Self::Reset => "reset",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Group {
    pub name: String,
    pub state: GroupState,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Completion {
    Success,
    Failed,
    FailedToSpawn,
    Killed,
    Errored,
    DependencyFailed,
}

impl Completion {
    pub const fn label(self) -> &'static str {
        match self {
            Self::Success => "success",
            Self::Failed => "failed",
            Self::FailedToSpawn => "spawn failed",
            Self::Killed => "killed",
            Self::Errored => "errored",
            Self::DependencyFailed => "dependency failed",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TaskState {
    Locked,
    Stashed,
    Queued,
    Running,
    Paused,
    Completed(Completion),
}

impl TaskState {
    pub const fn label(self) -> &'static str {
        match self {
            Self::Locked => "locked",
            Self::Stashed => "stashed",
            Self::Queued => "queued",
            Self::Running => "running",
            Self::Paused => "paused",
            Self::Completed(completion) => completion.label(),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Task {
    pub id: TaskId,
    pub group: String,
    pub state: TaskState,
    pub label: String,
    pub command: String,
    pub path: String,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct QueueState {
    groups: Vec<Group>,
    tasks: Vec<Task>,
    task_indexes: BTreeMap<TaskId, usize>,
}

impl QueueState {
    pub(crate) fn new(groups: Vec<Group>, tasks: Vec<Task>) -> Self {
        let task_indexes = tasks
            .iter()
            .enumerate()
            .map(|(index, task)| (task.id, index))
            .collect();
        let state = Self {
            groups,
            tasks,
            task_indexes,
        };
        debug_assert_eq!(state.tasks.len(), state.task_indexes.len());
        debug_assert!(state
            .tasks
            .windows(PAIR_WINDOW_SIZE)
            .all(|pair| pair[0].group < pair[1].group
                || (pair[0].group == pair[1].group && pair[0].id < pair[1].id)));
        state
    }

    pub fn groups(&self) -> &[Group] {
        &self.groups
    }

    pub fn tasks(&self) -> &[Task] {
        &self.tasks
    }

    pub fn task(&self, id: TaskId) -> Option<&Task> {
        self.task_indexes
            .get(&id)
            .and_then(|index| self.tasks.get(*index))
    }

    pub fn first_task_id(&self) -> Option<TaskId> {
        self.tasks.first().map(|task| task.id)
    }

    pub(crate) fn task_position(&self, id: TaskId) -> Option<usize> {
        self.task_indexes.get(&id).copied()
    }
}
