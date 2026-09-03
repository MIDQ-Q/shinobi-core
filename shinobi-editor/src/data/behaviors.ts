import { Behavior, PhaseType } from '../types/jutsu';

// Здесь будут все 300+ поведений из generator.md. 
// Пока добавлены ключевые примеры для проверки работы UI.
export const BEHAVIORS: Behavior[] = [
  {
    id: 'trigger_handseals',
    phase: 'trigger',
    name: 'Печати рук',
    description: 'Каст с анимацией печатей',
    params: [
      { name: 'sealCount', type: 'number', default: 3, min: 1, max: 10, description: 'Количество печатей' },
      { name: 'sealSpeed', type: 'number', default: 1.0, min: 0.5, max: 3.0, step: 0.1, description: 'Сскорость печатей' }
    ],
    loreExamples: ['Огненный шар', 'Водяной дракон']
  },
  {
    id: 'deliver_projectile',
    phase: 'delivery',
    name: 'Снаряд',
    description: 'Летящий объект',
    params: [
      { name: 'speed', type: 'number', default: 1.5, min: 0.5, max: 5.0, step: 0.1, description: 'Скорость' },
      { name: 'size', type: 'number', default: 0.5, min: 0.1, max: 3.0, step: 0.1, description: 'Размер' }
    ],
    loreExamples: ['Огненный шар', 'Кунай']
  },
  {
    id: 'impact_damage',
    phase: 'contact',
    name: 'Урон',
    description: 'Прямой урон при попадании',
    params: [
      { name: 'damage', type: 'number', default: 8, min: 1, max: 50, step: 1, description: 'Количество урона' }
    ],
    loreExamples: ['Любой удар']
  },
  {
    id: 'status_burn',
    phase: 'status',
    name: 'Горение',
    description: 'Огненный урон со временем',
    params: [
      { name: 'damage', type: 'number', default: 1, min: 1, max: 10, step: 1, description: 'Урон за тик' },
      { name: 'duration', type: 'number', default: 40, min: 10, max: 200, step: 10, description: 'Длительность' }
    ],
    loreExamples: ['Амацерасу']
  }
];

export const getBehaviorById = (id: string): Behavior | undefined => {
  return BEHAVIORS.find(b => b.id === id);
};