type Handler = (payload: unknown) => void

const handlers = new Map<string, Set<Handler>>()

export interface AntaresEventBus {
  on(event: string, handler: Handler): void
  off(event: string, handler: Handler): void
  emit(event: string, payload?: unknown): void
  clear(): void
}

export function useEventBus(): AntaresEventBus {
  function on(event: string, handler: Handler): void {
    let set = handlers.get(event)
    if (set === undefined) {
      set = new Set()
      handlers.set(event, set)
    }
    set.add(handler)
  }

  function off(event: string, handler: Handler): void {
    cleanup(event, handler)
  }
  function cleanup(event: string, handler: Handler): void {
    handlers.get(event)?.delete(handler)
  }
  function emit(event: string, payload?: unknown): void {
    handlers.get(event)?.forEach((h) => h(payload))
  }
  function clear(): void {
    handlers.clear()
  }

  return { on, off, emit, clear }
}
