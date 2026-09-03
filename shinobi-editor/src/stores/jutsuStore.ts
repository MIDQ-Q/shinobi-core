import { create } from 'zustand';
import { JutsuDefinition, PhaseBehavior, PhaseType } from '../types/jutsu';
import { getBehaviorById } from '../data/behaviors';

interface JutsuStore {
  jutsu: JutsuDefinition;
  
  setJutsu: (jutsu: JutsuDefinition) => void;
  updateField: (field: keyof JutsuDefinition, value: any) => void;
  
  setPhaseBehavior: (phase: PhaseType, index: number, behavior: PhaseBehavior) => void;
  addPhaseBehavior: (phase: PhaseType, behaviorId: string) => void;
  removePhaseBehavior: (phase: PhaseType, index: number) => void;
  
  updateParam: (phase: PhaseType, index: number, paramName: string, value: number | string | boolean) => void;
  
  exportToJson: () => string;
  importFromJson: (json: string) => void;
  reset: () => void;
}

const createEmptyJutsu = (): JutsuDefinition => ({
  id: 'shinobicore:new_jutsu',
  name: 'New Jutsu',
  description: '',
  category: 'ninjutsu',
  element: null,
  rank: 'D',
  trigger: null,
  delivery: [],
  contact: [],
  area: [],
  status: [],
  duration: [],
  end: [],
  modifiers: [],
  baseCost: 20,
  baseDamage: 5,
  cooldown: 5.0,
});

export const useJutsuStore = create<JutsuStore>((set, get) => ({
  jutsu: createEmptyJutsu(),

  setJutsu: (jutsu) => set({ jutsu }),
  
  updateField: (field, value) => set((state) => ({
    jutsu: { ...state.jutsu, [field]: value }
  })),

  setPhaseBehavior: (phase, index, behavior) => set((state) => {
    const updated = [...state.jutsu[phase]];
    updated[index] = behavior;
    return { jutsu: { ...state.jutsu, [phase]: updated } };
  }),

  addPhaseBehavior: (phase, behaviorId) => {
    const behavior = getBehaviorById(behaviorId);
    if (!behavior) return;
    
    const defaultParams: Record<string, number | string | boolean> = {};
    behavior.params.forEach(p => {
      defaultParams[p.name] = p.default;
    });

    const newBehavior: PhaseBehavior = {
      behaviorId,
      params: defaultParams,
    };

    set((state) => ({
      jutsu: {
        ...state.jutsu,
        [phase]: [...state.jutsu[phase], newBehavior]
      }
    }));
  },

  removePhaseBehavior: (phase, index) => set((state) => ({
    jutsu: {
      ...state.jutsu,
      [phase]: state.jutsu[phase].filter((_, i) => i !== index)
    }
  })),

  updateParam: (phase, index, paramName, value) => set((state) => {
    const updated = [...state.jutsu[phase]];
    updated[index] = {
      ...updated[index],
      params: { ...updated[index].params, [paramName]: value }
    };
    return { jutsu: { ...state.jutsu, [phase]: updated } };
  }),

  exportToJson: () => {
    return JSON.stringify(get().jutsu, null, 2);
  },

  importFromJson: (json) => {
    try {
      const parsed = JSON.parse(json);
      set({ jutsu: parsed });
    } catch (e) {
      console.error('Failed to import JSON:', e);
    }
  },

  reset: () => set({ jutsu: createEmptyJutsu() }),
}));