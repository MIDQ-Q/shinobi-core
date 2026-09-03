import { create } from 'zustand';
import { JutsuDefinition, ElementType } from '../types/jutsu';

interface JutsuState {
  jutsu: Partial<JutsuDefinition>;
  setName: (name: string) => void;
  setNature: (nature: ElementType) => void;
  setParam: (key: string, value: any) => void;
}

const defaultJutsu: Partial<JutsuDefinition> = {
  id: 'shinobicore:new_jutsu',
  name: 'New Jutsu',
  category: 'elemental_ninjutsu',
  nature: 'fire',
  rank: 'D',
  baseCost: 35,
  baseDamage: 8,
  baseRange: 24,
  baseRadius: 3,
  cooldown: 4,
  strain: 6,
  leveling: { maxLevel: 10, scaling: {} },
  behaviorPipeline: []
};

export const useJutsuStore = create<JutsuState>((set) => ({
  jutsu: defaultJutsu,
  setName: (name) => set((state) => ({ 
    jutsu: { ...state.jutsu, name, id: `shinobicore:${name.toLowerCase().replace(/[^a-z0-9]+/g, '_')}` } 
  })),
  setNature: (nature) => set((state) => ({ 
    jutsu: { ...state.jutsu, nature } 
  })),
  setParam: (key, value) => set((state) => ({ 
    jutsu: { ...state.jutsu, [key]: value } 
  })),
}));