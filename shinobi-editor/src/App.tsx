import { useState } from 'react'
import { JutsuDefinition, Behavior, BehaviorPhase } from './types/jutsu'
import { BEHAVIORS } from './data/behaviors'
import PhaseTabs from './components/PhaseTabs'
import BehaviorList from './components/BehaviorList'
import ParameterEditor from './components/ParameterEditor'
import './App.css'

function App() {
  const [selectedPhase, setSelectedPhase] = useState<BehaviorPhase>('trigger')
  const [selectedBehavior, setSelectedBehavior] = useState<Behavior | null>(null)
  const [addedBehaviors, setAddedBehaviors] = useState<Array<{phase: BehaviorPhase, behavior: Behavior, params: Record<string, any>}>>([])
  const [techniqueName, setTechniqueName] = useState('')

  const handleBehaviorSelect = (behavior: Behavior) => {
    setSelectedBehavior(behavior)
  }

  const handleAddBehavior = () => {
    if (selectedBehavior) {
      const defaultParams: Record<string, any> = {}
      if (selectedBehavior.params) {
        Object.keys(selectedBehavior.params).forEach(key => {
          const param = selectedBehavior.params![key]
          defaultParams[key] = param.default
        })
      }
      
      setAddedBehaviors([
        ...addedBehaviors,
        {
          phase: selectedPhase,
          behavior: selectedBehavior,
          params: defaultParams
        }
      ])
    }
  }

  const handleRemoveBehavior = (index: number) => {
    setAddedBehaviors(addedBehaviors.filter((_, i) => i !== index))
  }

  const handleParamChange = (index: number, paramName: string, value: any) => {
    const updated = [...addedBehaviors]
    updated[index].params[paramName] = value
    setAddedBehaviors(updated)
  }

  const exportJSON = () => {
    const json: JutsuDefinition = {
      id: "custom:" + (techniqueName || "technique").toLowerCase().replace(/\s+/g, '_'),
      name: techniqueName || "Custom Technique",
      behaviorPipeline: addedBehaviors.map(ab => ({
        phase: ab.phase,
        behavior: ab.behavior.id,
        params: ab.params
      }))
    }
    
    const blob = new Blob([JSON.stringify(json, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `${json.id}.json`
    a.click()
    URL.revokeObjectURL(url)
  }

  const getBehaviorsForPhase = (phase: BehaviorPhase) => {
    return BEHAVIORS.filter(b => b.phase === phase)
  }

  return (
    <div className="app">
      <header className="app-header">
        <div>
          <h1> Shinobi Editor</h1>
          <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>
            Редактор техник для ShinobiCore
          </div>
        </div>
        <div className="header-actions">
          <input
            type="text"
            placeholder="Название техники..."
            value={techniqueName}
            onChange={(e) => setTechniqueName(e.target.value)}
            className="param-input"
            style={{ width: '200px' }}
          />
          <button className="btn btn-danger" onClick={() => setAddedBehaviors([])}>
             Сброс
          </button>
          <button className="btn btn-primary" onClick={exportJSON}>
            💾 Экспорт JSON
          </button>
        </div>
      </header>

      <div className="app-main">
        <aside className="sidebar">
          <div className="sidebar-header">
            <div className="sidebar-title">Доступные поведения</div>
            <div className="sidebar-count">
              {getBehaviorsForPhase(selectedPhase).length} в фазе "{selectedPhase}"
            </div>
          </div>
          <BehaviorList
            behaviors={getBehaviorsForPhase(selectedPhase)}
            selectedBehavior={selectedBehavior}
            onSelect={handleBehaviorSelect}
          />
        </aside>

        <main className="content">
          <PhaseTabs
            selectedPhase={selectedPhase}
            onSelect={setSelectedPhase}
          />

          <div className="editor-panel">
            {selectedBehavior ? (
              <div className="fade-in">
                <h2 className="section-title">
                  <span className="icon">
                    {selectedPhase === 'trigger' && '⚡'}
                    {selectedPhase === 'delivery' && ''}
                    {selectedPhase === 'contact' && '💥'}
                    {selectedPhase === 'area' && '🌊'}
                    {selectedPhase === 'status' && '✨'}
                    {selectedPhase === 'duration' && '⏱'}
                    {selectedPhase === 'end' && '🏁'}
                    {selectedPhase === 'mod' && '🔧'}
                  </span>
                  {selectedBehavior.name}
                </h2>
                
                <div className="param-group">
                  <div className="param-group-title">Параметры</div>
                  <ParameterEditor
                    behavior={selectedBehavior}
                    onAdd={handleAddBehavior}
                  />
                </div>

                <div className="added-behaviors">
                  <h3 className="section-title" style={{ fontSize: '14px' }}>
                    Добавлено в технику ({addedBehaviors.filter(b => b.phase === selectedPhase).length})
                  </h3>
                  {addedBehaviors
                    .filter(b => b.phase === selectedPhase)
                    .map((item, index) => (
                      <div key={index} className="added-behavior">
                        <div className="added-behavior-header">
                          <span className="added-behavior-name">{item.behavior.name}</span>
                          <button 
                            className="btn-remove"
                            onClick={() => handleRemoveBehavior(addedBehaviors.indexOf(item))}
                          >
                            ✕
                          </button>
                        </div>
                        <ParameterEditor
                          behavior={item.behavior}
                          values={item.params}
                          onChange={(param, value) => handleParamChange(addedBehaviors.indexOf(item), param, value)}
                          readonly
                        />
                      </div>
                    ))}
                </div>
              </div>
            ) : (
              <div className="empty-state">
                <div className="icon">📋</div>
                <h3>Выберите поведение</h3>
                <p>Кликните на любое поведение из списка слева, чтобы добавить его в технику</p>
              </div>
            )}

            {addedBehaviors.length > 0 && (
              <div className="json-preview">
                <strong>JSON Preview:</strong>
                <br />
                {JSON.stringify({
                  id: "custom:" + (techniqueName || "technique").toLowerCase().replace(/\s+/g, '_'),
                  name: techniqueName || "Custom Technique",
                  behaviorPipeline: addedBehaviors.map(ab => ({
                    phase: ab.phase,
                    behavior: ab.behavior.id,
                    params: ab.params
                  }))
                }, null, 2)}
              </div>
            )}
          </div>
        </main>
      </div>
    </div>
  )
}

export default App