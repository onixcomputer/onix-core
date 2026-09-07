// Remote sockets carry Herdr RPC, not access to the remote filesystem.
import { DEFAULT_SESSION_NAME } from "./sessions.ts";

export const REMOTE_FILES_UNAVAILABLE_STATUS = 501;
const SESSION_NAME = /^[a-zA-Z0-9][a-zA-Z0-9_-]*$/;

export function parseRemoteSessionNames(value: string | undefined): string[] {
  if (value === undefined || value.trim() === "") return [];
  const names = value.split(",").map((name) => name.trim());
  if (
    names.some(
      (name) => !SESSION_NAME.test(name) || name === DEFAULT_SESSION_NAME,
    )
  ) {
    throw new Error(
      "COLLIE_REMOTE_SESSIONS requires named sessions, not paths or default.",
    );
  }
  if (new Set(names).size !== names.length) {
    throw new Error("COLLIE_REMOTE_SESSIONS contains a duplicate session.");
  }
  return names;
}

export function hasLocalSessionFiles(
  name: string,
  remoteNames: readonly string[] = [],
): boolean {
  return !remoteNames.includes(name);
}
