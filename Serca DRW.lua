--[[

]]--
version = "3.0"

function ScoreReturn()
      x = current.GetEnergyScore()
return x-x%0.001
end
proteinLength=structure.GetCount ()
  -----------------------------------------------------------------------------------------------init
-- service slots are 3:
-- slot1 is used as basic one
-- slot100 - as the best unfuzed solution
-- slot99 used to store unfuzed version of the solution (only unfuzed versions are rebuild or get the full fuze!)
-- slot98 used to store fuzed version of the highest score solution
maxRebuildCount=96
sphereRadius=8
reportLevel=2
slotsToFuze=1
shakeOnRank=false
convertLoop=true
forceChange=false
unfuzeFirst=false
fullProtein=true
infiniteExecution = true
fuze2=false
saveLocal=false
shiftFuze = -1
currentFuze = 1
remixNotRebuild = false
consecutiveRounds = false

startCI = 0.05
endCI=behavior.GetClashImportance()
CI = endCI

energy2BBScoreRatio=2
selectionLength=13
OverlapSettings = true
ignoredSel = 0

overlap = 0
StartRebuild = 13
EndRebuild = 13

fuzeAfternoGain = math.max(2, math.floor(1200/proteinLength))
fuzeAfternoGain = math.min(30,fuzeAfternoGain)

fuzeAfternoGain_counter = 0
shiftNoGain_counter = 0
shiftFuze_counter = 0

startingAA=1
bestScore=ScoreReturn()
lastScore=-999999
currentBBScore=-999999
rebuildScores = {}
remixBBScores = {}, {}
rebuildScores[1]=bestScore
rebuildRetryNo=0
bestSelectNum=0
solutionsFound = 1
remixNum = #rebuildScores
undo.SetUndo(false)
freeSlot=97

selectionPresent=false
bestSlot=0
bestEnergySlot=0
selectionEnd=0
selectionStart=0
selNum=0
roundsWithNoGain = 0
FuzeNumber = 1

fuzeConfig = {
						"{1.00, 2, 0.05,20} {0.25, 2, 0.25,7} {1.00, 2, 1.00,20} {0.05, 1, 0.25,2} {1.00, 3, 1.00,20} ", --best score
						" {0.05, 3, 0.05,2} {1.00, -7, 1.00,2} {1.00, 3, 1.00,20}",	--fastest
						"{0.25, 1, 1.00,20} {0.05, 2, 0.05,7} {0.25, 3, 0.05,7} {1.00, -2, 1.00,20} {1.00, 3, 1.00,20} ", --best score
						" {0.05, 3, 0.05,2} {1.00, -7, 1.00,2} {1.00, 3, 1.00,20}",
						"{0.05, -2, 0.05,7} {0.25, 2, 0.25,7} {1.00, 3, 1.00,20}",	
						"{0.05, -2, 0.05,7} {1.00, 3, 1.00,7} {0.05, 2, 0.05,7} {0.25, 1, 0.25,2} {1.00, 3, 1.00,20}"
						}	--fastest

selDialog=selNum
selectionStartArr={}
selectionEndArr={}
solutionIDs = {}
action="Rebuild"

rebuiltResidues = {} 	--array to monitor changes in residues in all the solutions in slots

startScore=ScoreReturn()
startRoundScore = ScoreReturn()
initScore=ScoreReturn()  --the real start score that doesn't changes

print ("+++Starting score "..startScore.." saved to slot 1")

save.Quicksave(1)
slot1Score = ScoreReturn()
save.Quicksave(100)
recentbest.Save()

selection.DeselectAll() --Clear All The Selections On The Start for DRW!
save.SaveSecondaryStructure()
-----------------------------------------------------------------------------------------------main
function main()
	resetRebuiltResidues()

    FindSelection()
	
    tempSelNum=selNum
    
    if selNum==0 then selNum=1 end
    selDialog=selNum
  
    --Call Dialog with the options
    while requestResult~=1 do
      requestResult = RequestOptions()
      if requestResult == 0 then return end -- cancel button pressed by user
      if requestResult == 2 then selDialog=selDialog+1 end
      if requestResult == 3 then 
        SelectLoops() 
        FindSelection()
        --print (selNum,selDialog)
        selDialog=selNum
      end
      if selDialog>5 then selDialog=5 end
    end

    selNum=math.max(tempSelNum, selDialog, selNum)
	--print ("selNum", tempSelNum, selDialog, selNum)
	if fuzeAfternoGain > 0 then
		multiplier = GetMultiplier()
		CI = startCI
		behavior.SetClashImportance(CI)
	end

	--use solution from slot98 as reference to the Fuzed solution, only if solution in slot98 has more points.
	if (useSlot98) then 
		if reportLevel>2 then print ("Making Fuze for this unfuzed start", startScore) end
		Fuze2(fuzeConfig[1])
		if reportLevel>1 then print ("Fuzed to", ScoreReturn()) end
		if ScoreReturn() > startScore then
			save.Quicksave(98)
			save.Quicksave(100)
			startScore=ScoreReturn()
			startRoundScore = ScoreReturn()
			initScore=ScoreReturn() 
		end
	else
		save.Quicksave(98)
	end
	save.Quickload(1)

    --Report settings in output window
    strOutput=action..": "..maxRebuildCount.." / slots:"..slotsToFuze..". Range "..StartRebuild.." /"..EndRebuild
    if forceChange then strOutput=strOutput..", force changes" end
    --if infiniteExecution then strOutput=strOutput..", infinite" end
    if shakeOnRank then strOutput=strOutput..", shake" end
    if saveLocal then strOutput=strOutput..", saveLocal" end
    if reportLevel>2 then strOutput=strOutput..". ReportLevel="..reportLevel end
	strOutput = strOutput.."\n"
    if OverlapSettings then strOutput=strOutput.."  overlap" end
    if useSlot98 then strOutput=strOutput..", useSlot98" end
    if consecutiveRounds then strOutput=strOutput..", consecutiveRounds" end
    --if fuze2 then strOutput=strOutput..", fuze2" end
    if shiftFuze then strOutput=strOutput..", shiftFuze="..shiftFuze end
    if shiftNoGain then strOutput=strOutput..", shiftNoGain="..shiftNoGain end
    if fuzeAfternoGain then strOutput=strOutput..", fuzeNoGain="..fuzeAfternoGain end
    if stopAfter>0 then strOutput=strOutput..", stopAfter="..stopAfter end
    if ignoredSel>0 then strOutput=strOutput..", ignoredSel="..ignoredSel end
    if (reportLevel>1) then print (strOutput) end

    if (reportLevel>1) and (selNum>0) then 
      printSelections()
    end

    loopIter=1
    while (loopIter>0) or (stopAfter==0) do --for Infinite execution option

		loopIter=loopIter + 1

		if reportLevel>0 then printRow(1) end
		--print ("-------------------------------------------------")
		if (reportLevel>1) then print("Iteration", (loopIter-1)..".") end
		if stopAfter>0 and stopAfter<loopIter then loopIter=0 end --break while if not infinite execution

		if (startScore > startRoundScore) then 
			roundsWithNoGain = 0
			if consecutiveRounds then
				fuzeAfternoGain_counter = 0
				shiftNoGain_counter = 0
				shiftFuze_counter = 0
			end
		else
			if loopIter > 2 then --don't change the roundsWithNoGain when just entered the loop
				roundsWithNoGain = roundsWithNoGain + 1
				fuzeAfternoGain_counter = fuzeAfternoGain_counter + 1
				shiftNoGain_counter = shiftNoGain_counter + 1
				shiftFuze_counter = shiftFuze_counter + 1
				if reportLevel>1 then print ("roundsWithNoGain",roundsWithNoGain) end
			end
		end

		-- decrease rebuild length every roundsWithNoGain rounds that gained zero points
		if (loopIter>2) then
			-- switch to Fuzed version of the protein every fuzeAfternoGain rounds that gained zero points
			if (fuzeAfternoGain_counter >= fuzeAfternoGain) and (fuzeAfternoGain>0) then
				fuzeAfternoGain_counter = 0 --decremental counter to enter here once per fuzeAfternoGain rounds
				if CI < 0 then		--never enter here. needs to be deleted, it seems that there is no sense to experiment with CI
					CI = CI * multiplier
					if CI>=0.95 then CI = 1 end
					if reportLevel>2 then print ("new CI ", CI, "multiplier", multiplier) end
				end
				-- if we are stuck then we fuze a little bit and build the whole set of slot scores.
				lastScore = ScoreReturn()
				--save.SaveSolution("drw slot100 "..ScoreReturn())
				save.Quickload(98)
				save.Quicksave(100)
				--save.SaveSolution("drw slot98 "..ScoreReturn())
				startScore = ScoreReturn()
				FuzeNumber = FuzeNumber +1
				--if reportLevel>1 then print ("saved drw slot98 "..ScoreReturn()..", slot100 "..lastScore) end
				
				--fuzeAfternoGain = fuzeAfternoGain -1 --decrement when no results up to zero.
				save.Quickload(100)
				if reportLevel>1 then print ("NoGain "..roundsWithNoGain.." rounds. fuzeAfternoGain "..fuzeAfternoGain) end
				if reportLevel>1 then print ("Switched to fuzed version ".. ScoreReturn().." /"..startScore.." from "..lastScore) end
			end
			if (fuzeAfternoGain==0) then		--if ==0 then fuze at the end of the round
				lastScore = ScoreReturn()
				save.Quickload(98)
				save.Quicksave(100)
				if (reportLevel>1) and (lastScore ~= ScoreReturn()) then print ("Switched to fuzed slot98 ".. ScoreReturn().." /"..startScore.." from "..lastScore..". CI="..CI) end
			end

			--change the type of the fuze every shiftFuze rounds
			if (shiftFuze_counter >= shiftFuze) and (shiftFuze>0) then
				shiftFuze_counter = 0
				if currentFuze == 2 then 
					currentFuze = 1
					if reportLevel>1 then print ("Switched to Fuze1. (rounds with no gain="..shiftFuze..")") end
				else
					if reportLevel>1 then print ("Switched to Fuze2. (rounds with no gain="..shiftFuze..")") end
					currentFuze = 2
				end
			end

			--decrement selectionLength if no gains (and if fuzeAfternoGain is stuck)
			if (shiftNoGain_counter >= shiftNoGain) then
				shiftNoGain_counter = 0 --decremental counter to enter here once per shiftNoGain rounds
		
				selectionLength = selectionLength - 1  
				if selectionLength < EndRebuild then 
					selectionLength = EndRebuild
				end
				if reportLevel>1 then print ("NoGain "..roundsWithNoGain.." rounds. shiftNoGain "..shiftNoGain..". Length is "..selectionLength) end

				if OverlapSettings then overlap=SetOverlap(selectionLength) end
				SplitProteinBySelections()
				--roundsWithNoGain = 0
				startingAA = 1
			else  
				--shift selections start/end points to prevent rebuilding the same selection over and over 
				startingAA=startingAA-1 --current pointer for the selections markup on full rebuild (shift by one every iteration to prevent rebuilding the same pieces again and again)
			end
		end

		SplitProteinBySelections()
		sortedStartArr, sortedEndArr = SortSelections(selectionStartArr, selectionEndArr) --sort array ascending to rebuild worst segments first
		startRoundScore = startScore
		if reportLevel>1 then print ("Rebuild len: "..selectionLength, fuzeAfternoGain, ScoreReturn()) end

		for m=1, selNum do
			bestScore=-999999
			bestSlot=0
			selectionStart=sortedStartArr[m]  --selectionStartArr[m]
			selectionEnd=sortedEndArr[m] 	--selectionEndArr[m]
			solutionsFound = 1
			solutionSubscoresArray = {}
			
			if ignoredSel > 0 then 
				ignoredSel = ignoredSel-1
			else
				if reportLevel>1 then 
					print((loopIter-1).."."..m.."/"..selNum.." len "..selectionLength.." segs: "..selectionStart.."-"..selectionEnd..". F"..FuzeNumber..". Score "..startScore)
				end
				
				SetSelection()
				if convertLoop then 
				  save.LoadSecondaryStructure()
				  structure.SetSecondaryStructureSelected("l")
				end
				save.Quicksave(100)

				if (selectionEnd-selectionStart > 8)  and (remixNotRebuild) then 
					print("Selections larger than 9 segments not allowed for Remix") 
					remixNum=0
				else
					RebuildRemixSelected()
				end
				
				bestSelectNum = slotsToFuze 
				if bestSelectNum > remixNum then bestSelectNum=remixNum end

				if reportLevel>2 then print(remixNum, "solutions found on "..action..". Ranking best "..bestSelectNum) end

				--if there are some solutions then rebuild, else go to the next iteration on 'for' loop
				if remixNum > 0 then 

					SortByBackbone()
					   
					--Fuze slots and score best
					for i, remixBBScores in ipairs(remixBBScores) do
						if i <=bestSelectNum then 
							save.Quickload(remixBBScores.id)

							if bestSelectNum>1 then  --fuze on scoring stage only when 'slotsToFuze' setting is >1
								if (not saveLocal) then save.Quicksave(99) end
								Fuze2(fuzeConfig[2], remixBBScores.id)
								currentScore = ScoreReturn()
								currentBBScore = ScoreBBReturn()
								if (not saveLocal) then save.Quickload(99) end
							else
								currentScore = ScoreReturn()
								currentBBScore = ScoreBBReturn()
							end

							improve = roundX(currentScore-startScore)

							textBest=""
							if (currentScore > bestScore) then
								bestScore=currentScore
								bestSlot=remixBBScores.id
								textBest="*"
								save.Quicksave(remixBBScores.id)
								if (improve > 0) and (saveLocal) then save.Quicksave(100) end  --accept and save best
							end
							if (reportLevel>1) and (bestSelectNum+reportLevel>3) then print ("Stabilized slot", remixBBScores.id, " to bb "..currentBBScore, "score: "..currentScore, "/"..remixBBScores.rank, textBest) end
						end
					end

					------------ Final Fuze for the best selection

					save.Quickload(bestSlot)
					--structure.ShakeSidechainsAll (2)
					if reportLevel>2 then print("Fuzing best solution from slot", bestSlot) end
					--print ("bestSlot",bestSlot)
					currentScore=ScoreReturn() 
					
					if (fuzeAfternoGain>=0) then save.Quicksave(99) end		--save in service slot current when in Unfuzed mode
					freeSlot=97 	--slot to save temp fuze 
					if bestSlot == 97 then freeSlot =96 end
					
					--Fuze
					if not forceChange then --no need to fuze if forced the change
						Fuze2(fuzeConfig[1])
					end
					
					lastScore = ScoreReturn()
					if lastScore >= currentScore then --accept Fuze results if score is improved
						if (fuzeAfternoGain>=0) then
							if lastScore > startScore then save.Quicksave(98) end --store fuzed version to restore when stopping the script
							save.Quickload(99) 
							if reportLevel>3  then print ("scores:", lastScore, ScoreReturn()) end
						end
						currentScore = lastScore
						save.Quicksave(bestSlot) 
					else
						save.Quickload(bestSlot)
						if (ScoreReturn() > startScore) then  	--if improve then switch fuzed version to slot 100
							if reportLevel>1  then print ("Switched to locally fuzed version", ScoreReturn()) end
							save.Quicksave(98)
						end 
						currentScore=ScoreReturn() 
					end
					improve = roundX(currentScore-startScore)
				
					if (improve > 0) or (forceChange) then 
						if reportLevel>=0 then print ("Gained "..improve.." points. New best score: "..currentScore.." / "..ScoreReturn()) end
						if reportLevel>1  then print ("Total gain:", roundX(currentScore-initScore)) end
						save.Quicksave(100)
						startScore = currentScore

						currentRow = getRow(1)
						currentRow = changeRowValues(currentRow, selectionStart, selectionEnd)
						setRow(currentRow, 1)
						--if reportLevel>1 then printRow(1) end

					else
					  save.Quickload(100)
					  lastScore = ScoreReturn()
					  if reportLevel>2 then print("No improve ("..currentScore.."). Restored to "..startScore, "/", lastScore) end
					end 
					
					-- Last round of every Iteration 
					if (reportLevel>1) and (m==selNum) then
						if (improve>0) then print ("Gained this round: "..roundX(currentScore - startRoundScore).." points. Current score "..roundX(ScoreReturn())) end
						if (improve<=0) then --print 'Total gain' at the end of the round but prevent double print it when improve>0
							if (lastScore-initScore)>0 then print ("Total gain:", roundX(startScore-initScore)) end
						end

				  end
				end --if remixNum>0
				--printRow(1)
				if slotsToFuze > 1 then print ("-------------------------------------------------") end
			end --if ignoredSel >0
		
		end --for
    end --while
    
    Cleanup()
    
end -- function main()



-------------------------------------------------------------Dialog
function RequestOptions()
        
    ask=dialog.CreateDialog("Options: Rebuild/Remix selected"..version)
    
    ask.maxRebuildCount = dialog.AddSlider("Solutions Num",10,1,maxRebuildCount,0) --up to 98 slots possible (change 36 to 98 if needed)
    ask.slotsToFuze = dialog.AddSlider("Slots to fuze",slotsToFuze,1,36,0) --math.ceil(x^(5/14))) --3) = 2  --3=2 4=2 5=2 7=3 8=3  10=3 11=4 14=4  15=5 16=5 20=5  21=6  22=6 25=6  26=7 30=7  

    --ask.remixNotRebuild=dialog.AddCheckbox("Remix instead of Rebuild", remixNotRebuild)
    --ask.remixNotRebuild.value=false
    ask.convertLoop=dialog.AddCheckbox("Convert to Loop", convertLoop)
    
    --selections
    --ask.s1 = dialog.AddLabel("Selections")  
    ask.StartRebuild = dialog.AddSlider("Start Length",StartRebuild,2,proteinLength,0)
    ask.EndRebuild = dialog.AddSlider("End Length",EndRebuild,2,proteinLength,0)
    ask.OverlapSettings=dialog.AddCheckbox("Overlap", OverlapSettings)
    --ask.selectionStart1 = dialog.AddSlider("Overlap",selectionStartArr[1],0,proteinLength,0)

    --fuze options
    ask.l1 = dialog.AddLabel("Fuze:")
    ask.shakeOnRank=dialog.AddCheckbox("Shake solution on Rank stage", shakeOnRank)
    ask.saveLocal=dialog.AddCheckbox("Save local fuze", false)
    ask.forceChange=dialog.AddCheckbox("Force Changes (loss)", forceChange)
    --ask.doFuze=dialog.AddCheckbox("Store Fuzed", doFuze)

    ask.consecutiveRounds=dialog.AddCheckbox("Consecutive Rounds", consecutiveRounds)
	ask.fuzeAfternoGain = dialog.AddSlider("Fuze rndsNoGain",fuzeAfternoGain,-1,30,0)  --: -1 means that fuzed solution is accepted on highscore (traditional way). 0 - on round end. 1 - when 1 round with no gains
	--ask.shiftFuze = dialog.AddSlider("Fuze local",shiftFuze,-1,15,0) 	--: change rebuild length when there are shiftNoGain iterations with no gain
	ask.shiftNoGain = dialog.AddSlider("Shift rndsNoGain",8,-1,30,0) 	--: change rebuild length when the are shiftNoGain iterations with no gain
    --ask.startCI = dialog.AddSlider("startCI", 1, 0, 1.00, 2)
    ask.ignoredSel = dialog.AddSlider("SkipFirst X", 0,0, math.floor(proteinLength/2), 0)
    ask.reportLevel = dialog.AddSlider("Report detalization", reportLevel,1,4,0)
    --ask.fullProtein=dialog.AddCheckbox("Full protein Rebuild (selections ignored)", fullProtein)
    --ask.fuze2=dialog.AddCheckbox("Fuze2", false)
	ask.stopAfter = dialog.AddSlider("Stop After",0,0,100,0) 	--: change rebuild length when the are shiftNoGain iterations with no gain
    --ask.infiniteExecution=dialog.AddCheckbox("Infinite Execution", infiniteExecution)
    ask.useSlot98=dialog.AddCheckbox("Unfuzed version", false) 

    ask.OK = dialog.AddButton("OK",1) 
    --ask.addSelections = dialog.AddButton("AddSelection",2) 
    ask.selectLoops = dialog.AddButton("SelLoops",3) 
    ask.Cancel = dialog.AddButton("Cancel",0)
    
    returnVal=dialog.Show(ask)
	if returnVal > 0 then
		
		if returnVal==1 then maxRebuildCount=ask.maxRebuildCount.value end

		--remixNotRebuild=ask.remixNotRebuild.value
		forceChange=ask.forceChange.value
		shakeOnRank=ask.shakeOnRank.value
		saveLocal=ask.saveLocal.value
		reportLevel=ask.reportLevel.value
		--infiniteExecution=ask.infiniteExecution.value
		convertLoop = ask.convertLoop.value
		slotsToFuze=ask.slotsToFuze.value
		--fuze2=ask.fuze2.value
		stopAfter=ask.stopAfter.value
		startCI=1 --ask.startCI.value
		useSlot98 =ask.useSlot98.value
		consecutiveRounds =ask.consecutiveRounds.value
		--shiftFuze=ask.shiftFuze.value 

		OverlapSettings = ask.OverlapSettings.value
		fuzeAfternoGain=ask.fuzeAfternoGain.value 
		shiftNoGain=ask.shiftNoGain.value 
		ignoredSel=ask.ignoredSel.value 

		StartRebuild=ask.StartRebuild.value
		EndRebuild=ask.EndRebuild.value

		----fix some vars if needed
		if remixNotRebuild then 
			action="Remix" 
			if StartRebuild > 9  then 
				StartRebuild = 9 
				print ("StartRebuild more than 8 not available for Remix. Setting at 8")
			end
			if EndRebuild > 9  then 
				EndRebuild = 9 
				print ("EndRebuild more than 8 not available for Remix. Setting at 8") 
			end
		end

		if StartRebuild < EndRebuild then 
			temp = StartRebuild
			StartRebuild = EndRebuild
			EndRebuild = temp
		end
		selectionLength=StartRebuild

		if OverlapSettings then overlap=SetOverlap(selectionLength) end

		if slotsToFuze > maxRebuildCount then slotsToFuze = maxRebuildCount end
		--if slotsToFuze==1 then shakeOnRank=false end 

		if reportLevel>1 then 
			print ("Full Protein "..action) 
			print (action.." Length "..selectionLength..", Overlap "..overlap)
		end
		SplitProteinBySelections() --create the selections

		-- to add 0.5 to every highest subscore solution (round first decimal "bestSelectNum / 12". 10 is used as the first decimal floor basis)
		otherSubscoresAddRank = math.floor(bestSelectNum / 12 * 10 + 0.5) / 10 		


    else 
      print ("Canceled") 
    end

	return returnVal
end

function SetOverlap(selectionLength)
	overlap = math.ceil(selectionLength^(6/11)) -- math.floor(math.sqrt(selectionLength)) + 1 --decrease overlap basing on selectionLength: 5=2 6=2 7=3 8=3 9=3 10=4 11=4 12=4 13=5 14=5
	if selectionLength < 7 then overlap = overlap - 1 end --with a bit of correction for small rebuild values
	return overlap
end

--------------------------------------------------Set of service functions to monitor what parts of the protein in the accepted solution where actually rebuilt
--Using 2d array. Number of rows = number of occupied slots
--Number of columns = number residues. Each row contain zero value for the residues that werent changed and 1 if they were rebuild in this solution

-- Function to add a new row with 1 between startIndex and endIndex and 0 elsewhere
function addRow(startIndex, endIndex)
    local newRow = {}
    for j = 1, rebuiltResidues.numColumns do
        if j >= startIndex and j <= endIndex then
            newRow[j] = 1
        else
            newRow[j] = 0
        end
    end
    table.insert(rebuiltResidues, newRow)
end

-- Function to modify the row and increase values between selectionStart and selectionEnd by 1
-- If 9 is reached, continue with 'a', 'b', ..., 'z', then 'A', 'B', ..., 'Z'
function changeRowValues(row, selectionStart, selectionEnd)
    for j = selectionStart, selectionEnd do
        if j >= 1 and j <= #row then
            if row[j] == 9 then
                row[j] = 'a'
            elseif type(row[j]) == 'string' then
                if row[j] >= 'a' and row[j] < 'z' then
                    row[j] = string.char(string.byte(row[j]) + 1)
                elseif row[j] == 'z' then
                    row[j] = 'A'
                elseif row[j] >= 'A' and row[j] < 'Z' then
                    row[j] = string.char(string.byte(row[j]) + 1)
                elseif row[j] == 'Z' then
                    row[j] = 'Z'
                end
            elseif type(row[j]) == 'number' and row[j] >= 0 and row[j] < 9 then
                row[j] = row[j] + 1
            end
        end
    end
    return row
end
function getRow(rowNumber)
    if rebuiltResidues[rowNumber] then
        return rebuiltResidues[rowNumber]
    end
end
function setRow(sourceRow, destRowNumber)
    if rebuiltResidues[destRowNumber] then
        for j = 1, #sourceRow do
            rebuiltResidues[destRowNumber][j] = sourceRow[j]
        end
    end
end
-- Function to print the values of the specified row compactly
function printRow(rowNumber)
    if rebuiltResidues[rowNumber] then
        print(table.concat(rebuiltResidues[rowNumber], ""))
    end
end

function resetRebuiltResidues(rowNumber)
	if rowNumber~=nil and rowNumber~=0 then
		currentrow = getRow(rowNumber)	--save the row before reseting the table
	end
	rebuiltResidues = {} 
	rebuiltResidues.numColumns = proteinLength
	addRow(0, 0) --add and empty row for 'slot1'

	if rowNumber~=nil  and rowNumber~=0 then
		setRow(currentrow, 1)
		print (table.concat(rebuiltResidues[1], ""))
	end
end
-------------------------------------------------------------------------Selection functions

--selections
function FindSelection()
	selNum=0
	for k=1, proteinLength do
	  if selection.IsSelected(k) then 
		--find for selection start
		if k==1 then 
		  selNum=selNum+1
		  selectionStartArr[selNum]=k
		else  
		  if not selection.IsSelected(k-1) then 
			selNum=selNum+1
			selectionStartArr[selNum]=k 
		  end
		end
		
		--find the selection end
		if k==proteinLength then
		  selectionEndArr[selNum]=k
		else
		  if not selection.IsSelected(k+1) then selectionEndArr[selNum]=k end
		end
	   
	  end
	end

	--if no selection, select residues 3-6
	if selNum==0 then
	  selectionStartArr[1]=math.min(5,proteinLength)
	  selectionEndArr[1]=math.min(13,proteinLength)
	end
end

function SetSelection()
	selection.DeselectAll()
	for k=1, proteinLength do
		if (k>=selectionStart) and (k<=selectionEnd) then
			selection.Select (k)
		end
	end
end

function SelectLoops()
	selection.DeselectAll()
	looplength=0

	--select all loops with length >= 3
	for k=1, proteinLength do
	  --print (structure.GetSecondaryStructure(k))
	  if structure.GetSecondaryStructure(k) == 'L' then 
		looplength=looplength+1
		selection.Select (k) 
	  else
		if (looplength>0)  and (looplength<3) then  --deselect if loop is too short
		  for j=1, looplength do
			selection.Deselect (k-j)
		  end
		end
		looplength=0
	  end
	  
	  if (k==proteinLength) and (looplength==1) then selection.Deselect (k) end
	end
end
  
--markup selection of the full protein with some overlap
function SplitProteinBySelections ()
	selectionStartArr={}
	selectionEndArr={}
    k=0 -- used here as selection number 
    if (overlap>=selectionLength) or (overlap<0) then overlap=selectionLength-1 end
    if (startingAA+selectionLength-1 <= 1) then startingAA=1 end -- reset selection markup position counter (startingAA) to 1st protein residue if it is too low
    activeAA=startingAA --startingAA is set in main when running this function. activeAA used as the current pointer of the selection end
        
    --make first selections
    while (activeAA<1) do
      if (activeAA+selectionLength-1>=2) then --if next selection length is >=2
        k=k+1 
        selectionStartArr[k]=1
        selectionEndArr[k]=activeAA+selectionLength-1
      end
      activeAA=activeAA+selectionLength-overlap
    end
    
    --make further selections
    while activeAA+selectionLength-1 < proteinLength do
      k=k+1
      selectionStartArr[k]=activeAA
      selectionEndArr[k]=activeAA+selectionLength-1
      activeAA=selectionEndArr[k]-overlap+1
    end
        
    --make last selections
    while (proteinLength-activeAA+1>=2) do --if next selection length is >=2
      k=k+1
      selectionStartArr[k]=activeAA
      selectionEndArr[k]=proteinLength
      activeAA=activeAA+selectionLength-overlap
    end
    
    selNum=k
 end

function SetAllSelections()
	selection.DeselectAll()
	for j=1, selNum do
	  selectionStart=selectionStartArr[j]
	  selectionEnd=selectionEndArr[j]
	  if (selectionEnd-selectionStart < 0) then
		temp = selectionStart
		selectionStart = selectionEnd
		selectionEnd = temp
	  end
	  if (reportLevel>3) then print ("Setting selection"..j.."/"..selNum..": ", selectionStart.."-"..selectionEnd) end
	  for k=1, proteinLength do
		if (k>=selectionStart) and (k<=selectionEnd) then
		  selection.Select (k)
		end
	  end
	end
end

-- Select everything in radius sphereRadius(=8) near any selected segment.
function SelectionSphere()
	--dump selection to array
	selectedSegs={}
	for k=1, proteinLength do
	  if selection.IsSelected(k) then  
		selectedSegs[k]=1
	  else
		selectedSegs[k]=0
	  end
	end

	for k=1, proteinLength do
	  for j=1, proteinLength do
		dist_str = structure.GetDistance(k, j)
		if (selectedSegs[j] == 1) and (dist_str < sphereRadius) then
		   selection.Select(k)
		end
	  end
	end
end
  
function printSelections()
	strOutput2=""
	print ("Found "..selNum.." selections")
	for j=1, selNum do
	  if (selNum>5) then 
		strOutput2=strOutput2.."   "..selectionStartArr[j].."-"..selectionEndArr[j]
		if (math.fmod(j, 7)==6) then strOutput2=strOutput2.."\n" end
	  else
		print (selectionStartArr[j].."-"..selectionEndArr[j])
	  end
	end
	if (selNum>5) then print(strOutput2) end
end

  --------------------------------------------------------------FUZE
function makeShake()
    behavior.SetClashImportance(1)
    structure.ShakeSidechainsAll (2)
end
function TinyFuze()
    SelectionSphere()
    behavior.SetClashImportance(0.05)
    structure.ShakeSidechainsSelected(1)
    behavior.SetClashImportance(1*CI)
    SetSelection()
end
function SphereFuze()
    SelectionSphere()
    behavior.SetClashImportance(0.05)
    structure.LocalWiggleSelected (2, 0, 1) --wiggle sidechains
    structure.LocalWiggleAll(5)	
    
    behavior.SetClashImportance(1) 
    structure.LocalWiggleSelected(3, 0, 1) --wiggle sidechains
    undo.SetUndo(true) 
    structure.LocalWiggleAll(15)
    undo.SetUndo(false) 
end
function SphereFuze2() --this one seems to be better than prev?
    behavior.SetClashImportance(0.05)
    structure.ShakeSidechainsAll(1) --wiggle sidechains
    structure.LocalWiggleAll(5)	
    
    behavior.SetClashImportance(1) 
    structure.LocalWiggleAll(5, 0, 1) --wiggle sidechains
    undo.SetUndo(true) 
    structure.LocalWiggleAll(20)
    undo.SetUndo(false) 
end
function SphereFuzeLocal() --not used
    SelectionSphere()
    behavior.SetClashImportance(0.05)
    structure.LocalWiggleSelected (2, 0, 1) --wiggle sidechains
    --SetSelection()
    structure.LocalWiggleSelected(5)	
    
    behavior.SetClashImportance(1) --behavior.SetClashImportance(1*CI)
    structure.LocalWiggleSelected(3, 0, 1) --wiggle sidechains
    undo.SetUndo(true)  --disable undo for everything except fuze
    structure.LocalWiggleSelected(15)
    undo.SetUndo(false) 
end

-- Function to parse the input string into a 2D array
function parseInput(input)
    local result = {}
    for quadruplet in input:gmatch("{([^}]+)}") do
        local values = {}
        for value in quadruplet:gmatch("[^,%s]+") do
            table.insert(values, tonumber(value))
        end
        table.insert(result, {
            clashImportance = values[1],
            shakeIter = values[2],
            clashImportance2= values[3],
            wiggleIter = values[4]
        })
    end
    return result
end
-- Universal function that runs the logic on parsed input
function Fuze2(inputString, slotx)
	--inputString = "{0.25, 2, 0.25,20} {1.00, 1, 1.00,2} {0.05, 3, 0.25,2} {0.25, -7, 0.25,20} {1.00, 3, 1.00,20}" --best score
	--inputString = "{0.25, 2, 0.25,20} {1.00, 1, 1.00,2} {0.05, 3, 0.25,2} {0.25, -7, 0.25,20} {1.00, 3, 1.00,20}" --best score
	--inputString = "{0.05, -2, 0.05,7} {1.00, 3, 1.00,7} {0.05, 2, 0.05,7} {0.25, 1, 0.25,2} {1.00, 3, 1.00,20}" --best score
	--inputString =  "{0.05, -2, 0.05,7} {0.25, 2, 0.25,7} {1.00, 3, 1.00,20}" --fastest
	--print (inputString)

    local fuzeConfig = parseInput(inputString)
    local score = ScoreReturn()
    if freeSlot == 0 or freeSlot == nil then 
        freeSlot = 97
    end
    save.Quicksave(freeSlot)

    for idx, triplet in ipairs(fuzeConfig) do
        behavior.SetClashImportance(triplet.clashImportance)
        if triplet.shakeIter and triplet.shakeIter > 0 then
            structure.ShakeSidechainsAll(triplet.shakeIter)
        elseif triplet.shakeIter and triplet.shakeIter < 0 then
            structure.LocalWiggleAll(-triplet.shakeIter, false, true)
        end
        
        -- Save quicksave to slotx if it is the first quadruplet and slotx is set
        if slotx and idx == 1 then 
            save.Quicksave(slotx)
        end
        
        behavior.SetClashImportance(triplet.clashImportance2)
        if triplet.wiggleIter and triplet.wiggleIter > 0 then
            structure.LocalWiggleAll(triplet.wiggleIter)
        elseif triplet.wiggleIter and triplet.wiggleIter < 0 then
            structure.LocalWiggleAll(-triplet.wiggleIter, true, false)
        end

        if idx == #fuzeConfig then 
            if ScoreReturn() > score then
                score = ScoreReturn()
                save.Quicksave(freeSlot)
            else
                save.Quickload(freeSlot)
            end
        end
    end

    return score -- Return the score
end

---

function Fuze_low() --not used
	currentScore1=ScoreReturn()

	behavior.SetClashImportance(0.05)
	structure.ShakeSidechainsAll (1)
	structure.WiggleAll (5)

	behavior.SetClashImportance(0.05)
	structure.WiggleAll (3)
	behavior.SetClashImportance(1*CI)
	undo.SetUndo(true)
	structure.WiggleAll (20)
	undo.SetUndo(false) 
	if reportLevel > 3 then print ("fuze finished at", ScoreReturn()) end
	if convertLoop then save.LoadSecondaryStructure() end
end

function Fuze3()
	currentScore1=ScoreReturn()

	if freeSlot==0 or freeSlot==nil then 
		freeSlot=97
  	end
  	save.Quicksave(freeSlot) 
	
	behavior.SetClashImportance(0.05)
	structure.ShakeSidechainsAll (1)
	structure.LocalWiggleAll (2)

	behavior.SetClashImportance(0.25)
	structure.LocalWiggleAll (2, 0, 1)
	structure.LocalWiggleAll (2)

	behavior.SetClashImportance(1)
	structure.ShakeSidechainsAll (1)
	undo.SetUndo(true) 
	structure.LocalWiggleAll (5, 1, 0)
	undo.SetUndo(false) 
	
	if ScoreReturn() > currentScore1 then 
	  save.Quicksave(bestSlot) 
	  currentScore1=ScoreReturn()
	end

	behavior.SetClashImportance(0.25)
	structure.ShakeSidechainsAll (1)
	structure.LocalWiggleAll (2)

	behavior.SetClashImportance(1)
	undo.SetUndo(true)
	structure.LocalWiggleAll (20)
	undo.SetUndo(false) 

	if ScoreReturn() > currentScore1 then 
	  save.Quicksave(freeSlot) 
	else save.Quickload(freeSlot) end

	if reportLevel > 3 then print ("fuze finished at", ScoreReturn()) end
	if convertLoop then save.LoadSecondaryStructure() end
end

function Fuze()
	currentScore1=ScoreReturn()

	if freeSlot==0 or freeSlot==nil then 
		freeSlot=97
  	end
	if bestSlot==0 or bestSlot==nil then 
		bestSlot=99
  	end
  	save.Quicksave(freeSlot) 
  	 
	if convertLoop then save.LoadSecondaryStructure() end
	
	behavior.SetClashImportance(0.05)
	structure.ShakeSidechainsAll (1)
	--save shake for score stability
	save.Quicksave(bestSlot)  
	structure.WiggleAll (2)

	behavior.SetClashImportance(0.25)
	structure.WiggleAll (2, 0, 1)
	structure.WiggleAll (2)

	behavior.SetClashImportance(1)
	structure.ShakeSidechainsAll (1)
	undo.SetUndo(true) 
	structure.WiggleAll (5, 1, 0)
	undo.SetUndo(false) 
	
	if ScoreReturn() > currentScore1 then 
	  save.Quicksave(freeSlot) 
	  currentScore1=ScoreReturn()
	end

	behavior.SetClashImportance(0.25)
	structure.ShakeSidechainsAll (1)
	structure.WiggleAll (2)

	behavior.SetClashImportance(1)
	undo.SetUndo(true)
	structure.WiggleAll (20)
	undo.SetUndo(false) 

	if ScoreReturn() > currentScore1 then 
	  save.Quicksave(freeSlot) 
	else save.Quickload(freeSlot) end

	if reportLevel > 3 then print ("fuze finished at", ScoreReturn()) end

end


--------------------------------------------------------------Rebuild/Remix
-- Function to get the list of SolutionIDs with the highest subscore for each score part
function GetHighestSolutionIDs(solutionSubscoresArray)
    local highestSolutionIDs = {}
	if reportLevel > 3 then print("Length of the solutionSubscoresArray:", #solutionSubscoresArray) end

    -- Iterate over each score part
    for scorePart, _ in pairs(solutionSubscoresArray[1]) do
        local maxSubscore = -999999
		local minSubscore =  999999
        local maxSolutionIDs = {}
        -- Iterate over each solution subscores
        for _, subscores in ipairs(solutionSubscoresArray) do
            local subscore = subscores[scorePart]
            local solutionID = subscores["SolutionID"]
            -- find the max value between all the solutions for secific subscore
			if subscore > maxSubscore then
				maxSubscore = subscore
				maxSolutionIDs = {solutionID}
			elseif subscore == maxSubscore then
				table.insert(maxSolutionIDs, solutionID)
			end

			-- Track the minimum subscore to prevent including in highestSolutionIDs array subscores with the same values for all the solutions
			if subscore < minSubscore then
				minSubscore = subscore
			end
        end

        if maxSubscore ~= minSubscore then
            highestSolutionIDs[scorePart] = maxSolutionIDs
		end
    end

    -- Return the list of SolutionIDs with the highest non-zero subscore for each score part
    return highestSolutionIDs
end

function SortByBackbone()
	bestEnergySlot=0

	--add few best energy score for solutions
	table.sort(remixBBScores, function(a,b) return a.score > b.score end)
	for i, remixBBScores in ipairs(remixBBScores) do
		if i <= bestSelectNum then remixBBScores.rank=(bestSelectNum-i)/energy2BBScoreRatio end  --add rank points to top energy solutions half to bb points by default
	end

	--add few best backbone score solutions
	table.sort(remixBBScores, function(a,b) return a.scoreBB > b.scoreBB end)
	for i, remixBBScores in ipairs(remixBBScores) do
		if i <= bestSelectNum then remixBBScores.rank=remixBBScores.rank+bestSelectNum+1-i end  --add rank points to best backbone solutions
	end

	highestSolutionIDs = GetHighestSolutionIDs(solutionSubscoresArray)

	for scorePart, solutionIDs in pairs(highestSolutionIDs) do
		if reportLevel>4 then print(" Solution ID with highest",scorePart," subscore:", table.concat(solutionIDs, ", ")) end
	end

	--sort by rank
	table.sort(remixBBScores, function(a,b) return a.rank > b.rank end)
	for i, remixBBScores in ipairs(remixBBScores) do
		if (i<=bestSelectNum) then
			if reportLevel>2 then print("Backbone score", remixBBScores.scoreBB, "from slot", remixBBScores.id, "score: "..remixBBScores.score, "/"..remixBBScores.rank) end
		end
	end

	-- increase the rank for solutions found in highestSolutionIDs
    for _, remixBBScores in ipairs(remixBBScores) do
        local solutionID = remixBBScores.id
        for _, solutionIDs in pairs(highestSolutionIDs) do
            for _, id in ipairs(solutionIDs) do
                if id == solutionID then
                    remixBBScores.rank = remixBBScores.rank + otherSubscoresAddRank		--otherSubscoresAddRank is based on bestSelectNum /8
                end
            end
        end
    end
	table.sort(remixBBScores, function(a,b) return a.rank > b.rank end)

end

	function CheckRepeats()
		currentScore=ScoreReturn()
		isDuplicate=false
		remixNum= #rebuildScores
		  
		for k=1, remixNum do
		  if rebuildScores[k] == currentScore then isDuplicate=true end
		end
		if not isDuplicate then 
		  solutionsFound = solutionsFound+1
		  rebuildScores[solutionsFound] = currentScore
		  save.Quicksave(solutionsFound)
		  if shakeOnRank then TinyFuze() end --makes a small shake before ranking energy score of rebuild (if checkbox was selected).
		  currentScore=ScoreReturn()
		  remixBBScores[solutionsFound-1] = {id = solutionsFound, scoreBB=ScoreBBReturn(), score=currentScore, rank=0}
		  
		  if reportLevel>2 then print ( "Slot", solutionsFound, "backbone", ScoreBBReturn(), "score", currentScore) end
		  --if reportLevel==2 then io.write(".") end
		else 
		  if reportLevel>2 then print (currentScore, "is duplicated to already found.") end
		end

		return isDuplicate
	end

function RebuildToSlots()
	j=0
	rebuildIter=1
	undo.SetUndo(false) 
	while (j<maxRebuildCount) and (rebuildIter<7) do
		j=j+1
		structure.RebuildSelected(rebuildIter)
		if CheckRepeats() then 
			j=j-1
			rebuildIter = rebuildIter+1
			--print (rebuildIter)
		else
			rebuildIter=1
			save.Quicksave(j+1)
			temp = GetSolutionSubscores(j+1)
			table.insert(solutionSubscoresArray, temp) --saving all the subscores of current solution in an Array to find later the one with the highest value on each subscore
		end
		save.Quickload(100)
	end
	undo.SetUndo(true) 
	return j
end

function remixBBscoreList()
	for i=1, remixNum do
		save.Quickload(i+1)
		if shakeOnRank then  --makes a small shake before ranking energy score of rebuild (if checkbox was selected).
			TinyFuze()
		end
		save.Quicksave(i+1)
		currentScore=ScoreReturn()
		temp = GetSolutionSubscores(i+1)
		table.insert(solutionSubscoresArray, temp) --saving all the subscores of current solution in an Array to find later the one with the highest value on each subscore
		if reportLevel>2 then print ( "Slot", i+1, "score", currentScore, "backbone", ScoreBBReturn()) end
		--if reportLevel==2 then io.write(".") end
		remixBBScores[i] = {id = i, scoreBB=ScoreBBReturn(), score=currentScore, rank=0}
	end
	--if reportLevel==2 then io.write("\n") end
end

function RebuildRemixSelected()
	if remixNotRebuild then
		remixNum = structure.RemixSelected(2, maxRebuildCount)
		if (remixNum>0) then remixBBscoreList() end
	else
		remixNum = RebuildToSlots()
		--remixNum=#rebuildScores-1
	end
end

--------------------------------------------------
-- Define a function to calculate energy score per number of segments for a selection
function CalculateSelectionEnergyPerSegment(start, finish)
	local segmentCount = finish - start + 1
	local energyScore = 0
	for i = start, finish do
		--energyScore = energyScore + current.GetSegmentEnergyScore(i)
		energyScore = energyScore + GetSegmentBBScore(i)
	end
	return energyScore / segmentCount
end

-- Define a function to sort selections based on energy score per number of segments
function SortSelections(selectionStartArr, selectionEndArr)
	-- Create a table to store selection indices, their corresponding energy scores per segment, start index, and end index
	local sortedSelections = {}

	-- Calculate and store energy scores per segment for each selection
	for i = 1, #selectionStartArr do
		local start = selectionStartArr[i]
		local finish = selectionEndArr[i]
		local energyScorePerSegment = CalculateSelectionEnergyPerSegment(start, finish)
		table.insert(sortedSelections, {index = i, start = start, finish = finish, scorePerSegment = energyScorePerSegment})
	end

	-- Sort the sortedSelections table based on energy scores per segment in ascending order
	table.sort(sortedSelections, function(a, b) return a.scorePerSegment < b.scorePerSegment end)

	-- Print the start index, end index, energy score per segment of each selection, and the sorted start and end indices
	for _, selection in ipairs(sortedSelections) do
		if reportLevel>3 then print("Start index:", selection.start, "- End index:", selection.finish, "- Energy", selection.scorePerSegment) end
	end

	-- Return the sorted arrays
	local sortedStartArr = {}
	local sortedEndArr = {}
	for _, selection in ipairs(sortedSelections) do
		table.insert(sortedStartArr, selection.start)
		table.insert(sortedEndArr, selection.finish)
	end

	return sortedStartArr, sortedEndArr
end
---------------------------------------------------------------service functions
function roundX(x)--cut all afer 3-rd place
return x-x%0.01
end

--[[ function returning the max between two numbers --]]
function max(num1, num2)
   if (num1 > num2) then  result = num1
   else result = num2    end
   return result
end

--	BackBone-Score is just the general score without clashing. Clashing is usefull to ignore when there is need to rank a lot of the Rebuild solutions very fast without the Fuze.
function ScoreBBReturn()
    x = 0
    for i=1, proteinLength do
      x = x + current.GetSegmentEnergySubscore(i, "Clashing")
    end
    x = current.GetEnergyScore() - x
	return x-x%1
end

-- Create array of the Scores for every Subscore of the puzzle
function GetSolutionSubscores(SolutionID)
    local scoreParts = puzzle.GetPuzzleSubscoreNames()
    local solutionSubscores = {}

	-- Iterate over each score part
	for _, scorePart in ipairs(scoreParts) do
		local currentSubscore = 0
		-- Iterate over each segment and calculate subscore
		for segmentIndex = 1, proteinLength do
			currentSubscore = currentSubscore + current.GetSegmentEnergySubscore(segmentIndex, scorePart)
		end
		solutionSubscores[scorePart] = currentSubscore
	end

	solutionSubscores["SolutionID"] = SolutionID
    return solutionSubscores
end

function GetSegmentBBScore(i)
	return current.GetSegmentEnergyScore(i) - current.GetSegmentEnergySubscore(i, "Clashing")
end

-- for fuzeAfternoGain we should calculate the multtiplier to increment Clashing Importance. Number of steps is equal to fuzeAfternoGain
function GetMultiplier()
	multiplier = endCI / startCI
	-- Calculate the multiplier needed in each step
	multiplier = multiplier ^ (1 / fuzeAfternoGain)
	print ("multiplier", multiplier, " endCI / startCI",  endCI, startCI)
	return multiplier
end

----------------------------------------------------------
  function Cleanup(err)
    currentScore=ScoreReturn()
	behavior.SetClashImportance(endCI)
    undo.SetUndo(true) 

    if (currentScore > startScore) then save.Quicksave(98) 
    else save.Quickload(98)  end

	if (fuzeAfternoGain>=0) then  save.Quickload(98) end
    currentScore=ScoreReturn()
    
    if (currentScore > initScore) then
      print ("Total gain:", roundX(currentScore-initScore))
    else
      save.Quickload(1)
      print("No improve. Restored to "..ScoreReturn())
    end
      
	save.Quickload(1)
	save.Quickload(100)
	save.Quickload(98)
	print (err)

    --if convertLoop then save.LoadSecondaryStructure() end
  end
-------------------------------------------------------------

xpcall ( main , Cleanup )

