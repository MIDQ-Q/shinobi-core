export type PhaseType = 'trigger' | 'delivery' | 'contact' | 'area' | 'status' | 'duration' | 'end' | 'modifier';

export interface BehaviorParam {
  name: string;
  type: 'number' | 'string' | 'boolean' | 'select';
  default: number | string | boolean;
  min?: number;
  max?: number;
  step?: number;
  options?: string[];
  description: string;
}

export interface Behavior {
  id: string;
  phase: PhaseType;
  name: string;
  description: string;
  params: BehaviorParam[];
  loreExamples?: string[];
}

export interface PhaseBehavior {
  behaviorId: string;
  params: Record<string, number | string | boolean>;
}

export interface JutsuDefinition {
  id: string;
  name: string;
  description: string;
  category: string;
  element: string | null;
  rank: string;
  trigger: PhaseBehavior | null;
  delivery: PhaseBehavior[];
  contact: PhaseBehavior[];
  area: PhaseBehavior[];
  status: PhaseBehavior[];
  duration: PhaseBehavior[];
  end: PhaseBehavior[];
  modifiers: PhaseBehavior[];
  baseCost: number;
  baseDamage: number;
  cooldown: number;
}