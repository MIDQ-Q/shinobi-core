import { PhaseType } from '../types/jutsu';
import { BEHAVIORS } from '../data/behaviors';

interface BehaviorListProps {
  phase: PhaseType;
  onAddBehavior: (id: string) => void;
  currentCount: number;
}

export function BehaviorList({ phase, onAddBehavior, currentCount }: BehaviorListProps) {
  const behaviors = BEHAVIORS.filter(b => b.phase === phase);

  return (
    <div className="h-full overflow-y-auto">
      <div className="p-3 border-b border-zinc-800 bg-zinc-900/80 sticky top-0 z-10 backdrop-blur-sm">
        <h3 className="text-sm font-semibold text-zinc-300">
          Доступные поведения ({behaviors.length})
        </h3>
        <p className="text-xs text-zinc-500 mt-1">
          Добавлено: {currentCount}
        </p>
      </div>
      
      <div className="p-2 space-y-2">
        {behaviors.map((behavior) => (
          <button
            key={behavior.id}
            onClick={() => onAddBehavior(behavior.id)}
            className="w-full text-left p-3 bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 hover:border-orange-500/50 rounded transition-all group"
          >
            <div className="font-medium text-zinc-200 text-sm group-hover:text-orange-400 transition-colors">
              {behavior.name}
            </div>
            <div className="text-xs text-zinc-500 mt-1">
              {behavior.description}
            </div>
            {behavior.params.length > 0 && (
              <div className="text-[10px] text-zinc-600 mt-1.5 uppercase tracking-wider">
                Параметры: {behavior.params.map(p => p.name).join(', ')}
              </div>
            )}
          </button>
        ))}
      </div>
    </div>
  );
}