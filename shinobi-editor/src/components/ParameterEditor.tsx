import { PhaseType, PhaseBehavior } from '../types/jutsu';
import { getBehaviorById } from '../data/behaviors';

interface ParameterEditorProps {
  phase: PhaseType;
  behaviors: PhaseBehavior[];
  onUpdateParam: (index: number, paramName: string, value: number | string | boolean) => void;
  onRemove: (index: number) => void;
}

export function ParameterEditor({ phase, behaviors, onUpdateParam, onRemove }: ParameterEditorProps) {
  if (behaviors.length === 0) {
    return (
      <div className="flex items-center justify-center h-full text-zinc-500">
        <div className="text-center">
          <div className="text-4xl mb-2 opacity-50">📋</div>
          <div className="text-sm font-medium">Нет добавленных поведений</div>
          <div className="text-xs mt-1 text-zinc-600">Выберите поведение из списка слева</div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-4 space-y-4">
      {behaviors.map((behavior, index) => {
        const behaviorDef = getBehaviorById(behavior.behaviorId);
        if (!behaviorDef) return null;

        return (
          <div key={index} className="bg-zinc-900 border border-zinc-800 rounded-lg p-4 shadow-sm">
            <div className="flex justify-between items-start mb-4 pb-3 border-b border-zinc-800">
              <div>
                <h4 className="font-semibold text-zinc-100 text-base">{behaviorDef.name}</h4>
                <p className="text-xs text-zinc-500 mt-0.5">{behaviorDef.description}</p>
              </div>
              <button
                onClick={() => onRemove(index)}
                className="text-xs text-red-400 hover:text-red-300 hover:bg-red-400/10 px-2 py-1 rounded transition-colors"
              >
                Удалить
              </button>
            </div>

            <div className="space-y-4">
              {behaviorDef.params.map((param) => (
                <div key={param.name}>
                  <label className="block text-xs font-medium text-zinc-400 mb-1.5">
                    {param.name}
                    <span className="text-zinc-600 font-normal ml-1">({param.description})</span>
                  </label>
                  
                  {param.type === 'number' && (
                    <div className="flex gap-3 items-center">
                      <input
                        type="range"
                        min={param.min || 0}
                        max={param.max || 100}
                        step={param.step || 1}
                        value={behavior.params[param.name] as number ?? param.default}
                        onChange={(e) => onUpdateParam(index, param.name, parseFloat(e.target.value))}
                        className="flex-1 h-2 bg-zinc-800 rounded-lg appearance-none cursor-pointer accent-orange-500"
                      />
                      <input
                        type="number"
                        min={param.min || 0}
                        max={param.max || 100}
                        step={param.step || 1}
                        value={behavior.params[param.name] as number ?? param.default}
                        onChange={(e) => onUpdateParam(index, param.name, parseFloat(e.target.value))}
                        className="w-20 bg-zinc-800 border border-zinc-700 rounded px-2 py-1.5 text-sm text-zinc-200 focus:outline-none focus:border-orange-500 transition-colors"
                      />
                    </div>
                  )}

                  {param.type === 'string' && (
                    <input
                      type="text"
                      value={behavior.params[param.name] as string ?? param.default}
                      onChange={(e) => onUpdateParam(index, param.name, e.target.value)}
                      className="w-full bg-zinc-800 border border-zinc-700 rounded px-3 py-1.5 text-sm text-zinc-200 focus:outline-none focus:border-orange-500 transition-colors"
                    />
                  )}

                  {param.type === 'boolean' && (
                    <label className="flex items-center gap-3 cursor-pointer group">
                      <div className="relative">
                        <input
                          type="checkbox"
                          checked={behavior.params[param.name] as boolean ?? false}
                          onChange={(e) => onUpdateParam(index, param.name, e.target.checked)}
                          className="sr-only peer"
                        />
                        <div className="w-10 h-6 bg-zinc-700 peer-focus:outline-none peer-focus:ring-2 peer-focus:ring-orange-500/50 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-orange-600"></div>
                      </div>
                      <span className="text-sm text-zinc-300 group-hover:text-zinc-100 transition-colors">
                        {behavior.params[param.name] ? 'Включено' : 'Выключено'}
                      </span>
                    </label>
                  )}

                  {param.type === 'select' && param.options && (
                    <select
                      value={behavior.params[param.name] as string ?? param.default}
                      onChange={(e) => onUpdateParam(index, param.name, e.target.value)}
                      className="w-full bg-zinc-800 border border-zinc-700 rounded px-3 py-1.5 text-sm text-zinc-200 focus:outline-none focus:border-orange-500 transition-colors"
                    >
                      {param.options.map(opt => (
                        <option key={opt} value={opt}>{opt}</option>
                      ))}
                    </select>
                  )}
                </div>
              ))}
            </div>
          </div>
        );
      })}
    </div>
  );
}