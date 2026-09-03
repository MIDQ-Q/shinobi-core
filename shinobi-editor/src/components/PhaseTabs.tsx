import { PhaseType } from '../types/jutsu';

interface PhaseTabsProps {
  activePhase: PhaseType;
  onPhaseChange: (phase: PhaseType) => void;
}

const phases: { id: PhaseType; label: string; icon: string }[] = [
  { id: 'trigger', label: 'Триггер', icon: '⚡' },
  { id: 'delivery', label: 'Доставка', icon: '🎯' },
  { id: 'contact', label: 'Контакт', icon: '💥' },
  { id: 'area', label: 'Область', icon: '🌀' },
  { id: 'status', label: 'Статус', icon: '✨' },
  { id: 'duration', label: 'Длительность', icon: '⏱️' },
  { id: 'end', label: 'Завершение', icon: '🏁' },
  { id: 'modifier', label: 'Модификаторы', icon: '🔧' },
];

export function PhaseTabs({ activePhase, onPhaseChange }: PhaseTabsProps) {
  return (
    <div className="flex gap-1 bg-zinc-900 border-b border-zinc-800 px-2 py-1 overflow-x-auto">
      {phases.map((phase) => (
        <button
          key={phase.id}
          onClick={() => onPhaseChange(phase.id)}
          className={`px-3 py-2 rounded text-sm font-medium transition-colors whitespace-nowrap ${
            activePhase === phase.id
              ? 'bg-orange-600 text-white'
              : 'bg-zinc-800 text-zinc-400 hover:bg-zinc-700 hover:text-zinc-200'
          }`}
        >
          <span className="mr-1">{phase.icon}</span>
          {phase.label}
        </button>
      ))}
    </div>
  );
}