window.twentyfifty = {};

controller = null
choices = null
action = null
sector = null
comparator = null

execute = null
old_choices = []

cache = {}
callbacks = {}
timers = {}
requested = {}
mainPathwayTimer = null
preLoadHoverTimer = null

setup = (e) ->
  setVariablesFromURL()
  preLoadPathway(codeForChoices())
  execute = new e
  $(document).ready(documentReady)

documentReady = () ->
  unless $.jStorage.get('CostCaveatShown') == true
    $('#cost_caveats').show();
  execute.documentReady()
  loadMainPathway()
  $("a[title]").tooltip({delay: 0, position: 'top left', offset:[3,3],tip:'#tooltip'});

setVariablesFromURL = () ->
  url_elements = window.location.pathname.split( '/' )
  controller = url_elements[1]
  choices = choicesForCode(url_elements[2])
  action = url_elements[3]
  if action == 'costs_compared_within_sector'
    sector = url_elements[4]
  if url_elements[4] == 'comparator'
    comparator = url_elements[5]

float_to_letter_map = {1.0:"1", 1.1:"b", 1.2:"c", 1.3:"d", 1.4:"e", 1.5:"f", 1.6:"g", 1.7:"h", 1.8:"i", 1.9:"j", 2.0:"2", 2.1:"l", 2.2:"m", 2.3:"n", 2.4:"o", 2.5:"p", 2.6:"q", 2.7:"r", 2.8:"s", 2.9:"t", 3.0:"3", 3.1:"v", 3.2:"w", 3.3:"x", 3.4:"y", 3.5:"z", 3.6:"A", 3.7:"B", 3.8:"C", 3.9:"D", 0.0:"0", 4.0:"4"}

codeForChoices = (c = choices) ->
  cd = for choice in c
    float_to_letter_map[choice]
  cd.join('')

letter_to_float_map = {"1":1.0, "b":1.1, "c":1.2, "d":1.3, "e":1.4, "f":1.5, "g":1.6, "h":1.7, "i":1.8, "j":1.9, "2":2.0, "l":2.1, "m":2.2, "n":2.3, "o":2.4, "p":2.5, "q":2.6, "r":2.7, "s":2.8, "t":2.9, "3":3.0, "v":3.1, "w":3.2, "x":3.3, "y":3.4, "z":3.5, "A":3.6, "B":3.7, "C":3.8, "D":3.9, "0":0.0, "4":4.0}

choicesForCode = (newCode) ->
  for choice in newCode.split('')
    letter_to_float_map[choice]

getSector = () ->
  parseInt(sector)
    
switchSector = (new_sector) ->
  sector = new_sector
  window.location = url()

getComparator = () ->
  comparator

switchCompator = (new_comparator) ->
  comparator = new_comparator
  execute.switchComparator(comparator)

url = (options = {}) ->
  s = jQuery.extend({controller:controller, code: codeForChoices(), action:action, sector:sector, comparator: getComparator()},options)
  if s.action == 'costs_compared_within_sector' && s.sector?
    "/#{s.controller}/#{s.code}/#{s.action}/#{s.sector}"
  else if s.comparator?
    "/#{s.controller}/#{s.code}/#{s.action}/comparator/#{s.comparator}"
  else
    "/#{s.controller}/#{s.code}/#{s.action}"

go = (index,level) ->
  old_choices = choices.slice(0)
  choices[index] = level
  loadMainPathway()

preLoad = (index,level) ->
  clearInterval(preLoadHoverTimer) if preLoadHoverTimer?
  preLoadHoverTimer = setInterval( (() ->
    preload_choices = choices.slice(0)
    preload_choices[index] = level
    preload_code = codeForChoices(preload_choices)
    preLoadPathway(preload_code)),500)

switchView = (new_action) ->
  action = new_action
  window.location = url()
  
switchPathway = (new_code) ->
  old_choices = choices.slice(0)
  choices = choicesForCode(new_code)
  loadMainPathway() 

preLoadPathway = (preload_code) ->
  return false if cache[preload_code]? # Already loaded
  return false if requested[preload_code]? # Already requested
  requested[preload_code] = true
  $.getJSON(url({code:preload_code, action:'data'}), (data) ->
    if data?
      cache[data._id] = data
  )
    
loadMainPathway = (pushState = true) ->
  # Check if we haven't really moved
  return false if choices.join('') == old_choices.join('')
  # Update the controls, if neccesarry
  updateControls(old_choices,choices)
  
  main_code = codeForChoices()
  # Change the url if we can
  history.pushState(choices,main_code,url()) if pushState && history['pushState']?
  
  # Stop any previous timers
  clearInterval(mainPathwayTimer) if mainPathwayTimer?
  
  # Check the cache
  if cache[main_code]?
    execute.updateResults(cache[main_code])
    $('#calculating').hide()
    $('#message').show()
  else
    $('#calculating').show()
    $('#message').hide()
    
    requested[main_code] = true
    
    fetch = () ->
      $.getJSON(url({code:main_code, action:'data'}), (data) ->
        data ||= cache[main_code] # In case it arrived while we were waiting
        if data?
          cache[data._id] = data
          if data._id == codeForChoices()
            clearInterval(mainPathwayTimer)
            execute.updateResults(data)      
            $('#calculating').hide()
            $('#message').show()
      )
    
    mainPathwayTimer = setInterval(fetch,3000)
    fetch()

loadSecondaryPathway = (secondary_code,callback) ->
  if cache[secondary_code]?
    callback(cache[secondary_code])
  else
    fetch = () =>
      $.getJSON(url({code:secondary_code, action:'data'}), (data) =>
        data ||= cache[secondary_code] # In case it arrived while we were waiting
        if data?
          clearInterval(timer)
          cache[data._id] = data
          callback(data) 
      )
    timer = setInterval((() -> fetch() ),3000)
    fetch()
  
window.onpopstate = (event) ->
  if event.state
    old_choices = choices.slice(0)
    choices = event.state
    loadMainPathway(false)



updateControls = (old_choices,@choices) ->
  controls = $('#classic_controls')
  for choice, i in @choices
    old_choice = old_choices[i]
    unless choice == old_choices[i]

      old_choice_whole = Math.ceil(old_choice)
      old_choice_fraction = parseInt((old_choice % 1)*10)
      
      choice_whole = Math.ceil(choice)
      choice_fraction = parseInt((choice % 1)*10)
            
      row = controls.find("tr#r#{i}")
      
      # Revert the old
      row.find(".selected, .level#{old_choice_whole}, .level#{old_choice_whole}_#{old_choice_fraction}").removeClass("selected level#{old_choice_whole} level#{old_choice_whole}_#{old_choice_fraction}")
      unless old_choice_fraction == 0
        controls.find("#c#{i}l#{old_choice_whole}").text(old_choice_whole)
      
      # Setup the new
      row.find("#c#{i}l#{choice_whole}").addClass('selected')
      
      for c in [1..(choice_whole-1)]
        controls.find("#c#{i}l#{c}").addClass("level#{choice_whole}")
      unless choice_fraction == 0
        controls.find("#c#{i}l#{choice_whole}").text(choice)
        controls.find("#c#{i}l#{choice_whole}").addClass("level#{choice_whole}_#{choice_fraction}")
      else
        controls.find("#c#{i}l#{choice_whole}").addClass("level#{choice_whole}")

pathway_names =
  "1011111111111111011111100111111011110110110111011011": "Doesn't tackle climate change (All level 1)",
  "1011111111111111011111100444444044440420330444042011": "Maximum demand"
  "4044444444444444044344400111111011110110110111011011": "Maximum supply"
  "1011343331444311024311100442444034330420230443042014": "Friends of the Earth"
  "1022313331233213023312200442443034330410230444041023": "Campaign for Protection of Rural England"
  "2023322221221211032214200332344034440420230344032012": "Prof Nick Jenkins"
  "2022214441134111034332100342244042340420320334042014": "Mark Brinkley"
  "2022211111121221033322200342324023410220220344032012": "National Grid"
  "2023222221221311032312200232314013430220230243032013": "Energy Technologies Institute"
  "2022222221323212034311100342424024430320220443042021": "Atkins"
  "3022312222131111022322100342443014440220220244012043": "Mark Lynas"
  "j0h2cd2221121f1b032211p004314110433304202304320420121": "Analogous to Markal 3.26"
  "e0d3jrg221ci12110222112004423220444404202304440420141": "Higher renewables, more energy efficiency"
  "r013ce1111111111042233B002322220233302202102330220121": "Higher nuclear, less energy efficiency"
  "f023df111111111f0322123003223220333203102303430310221": "Higher CCS, more bioenergy"

pathway_descriptions = 
  "1011111111111111011111100111111011110110110111011011": "Imported natural gas for electricity and heat\nDoes not tackle climate change",
  "1011111111111111011111100444444044440420330444042011": "Maximum demand"
  "4044444444444444044344400111111011110110110111011011": "Maximum supply"
  "1011343331444311024311100442444034330420230443042014": "No nuclear or CCS - only renewables\nMassive demand reduction"
  "1022313331233213023312200442443034330410230444041023": "Lorem ipsum dolor sit amet, consectetur\nQuisque viverra luctus neque."
  "2023322221221211032214200332344034440420230344032012": "Lorem ipsum dolor sit amet, consectetur\nQuisque viverra luctus neque."
  "2022214441134111034332100342244042340420320334042014": "Lorem ipsum dolor sit amet, consectetur\nQuisque viverra luctus neque."
  "2022211111121221033322200342324023410220220344032012": "Lorem ipsum dolor sit amet, consectetur\nQuisque viverra luctus neque."
  "2023222221221311032312200232314013430220230243032013": "Lorem ipsum dolor sit amet, consectetur\nQuisque viverra luctus neque."
  "2022222221323212034311100342424024430320220443042021": "Lorem ipsum dolor sit amet, consectetur\nQuisque viverra luctus neque."
  "3022312222131111022322100342443014440220220244012043": "All vehicles and heaters are electric\nNuclear, offshore wind and geoequestration"
  "j0h2cd2221121f1b032211p004314110433304202304320420121": "An illustration of the kind of pathway that\nthe Markal cost optimising model suggests"
  "e0d3jrg221ci12110222112004423220444404202304440420141": "Lorem ipsum dolor sit amet, consectetur\nQuisque viverra luctus neque."
  "r013ce1111111111042233B002322220233302202102330220121": "Lorem ipsum dolor sit amet, consectetur\nQuisque viverra luctus neque."
  "f023df111111111f0322123003223220333203102303430310221": "Lorem ipsum dolor sit amet, consectetur\nQuisque viverra luctus neque."
  

pathwayName = (pathway_code,default_name = null) ->
  pathway_names[pathway_code] || default_name

pathwayDescriptions = (pathway_code,default_description = null) ->
  pathway_descriptions[pathway_code] || default_description

window.twentyfifty.setup = setup
window.twentyfifty.code = codeForChoices
window.twentyfifty.getSector = getSector
window.twentyfifty.switchSector = switchSector
window.twentyfifty.getComparator = getComparator
window.twentyfifty.switchCompator = switchCompator
window.twentyfifty.url = url
window.twentyfifty.go = go
window.twentyfifty.preLoad = preLoad
window.twentyfifty.preLoadPathway = preLoadPathway
window.twentyfifty.loadMainPathway = loadMainPathway
window.twentyfifty.loadSecondaryPathway = loadSecondaryPathway
window.twentyfifty.switchView = switchView
window.twentyfifty.switchPathway = switchPathway
window.twentyfifty.pathwayName = pathwayName
window.twentyfifty.pathwayDescriptions = pathwayDescriptions
