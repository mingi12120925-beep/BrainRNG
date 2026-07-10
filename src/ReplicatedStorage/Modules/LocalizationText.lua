local LocalizationText = {}

local LocalizationService = game:GetService("LocalizationService")

local DEFAULT_LOCALE = "en"

local translations = {
	ko = {
		["NextGoal.Prefix"] = "다음 목표",
		["NextGoal.GainIQ"] = "IQ 얻기",
		["NextGoal.ClaimQuest"] = "퀘스트 보상 받기",
		["NextGoal.OpenChest"] = "상자 열기",
		["NextGoal.FinishQuest"] = "퀘스트 완료하기",
		["NextGoal.DiscoverConcepts"] = "개념 발견하기",
		["NextGoal.HuntRareConcepts"] = "희귀 개념 찾기",
		["Button.Concepts"] = "개념",
		["Button.Quests"] = "퀘스트",
		["Button.Rewards"] = "보상",
		["Button.Luck"] = "운",
		["Button.Auto"] = "자동",
		["Button.Ready"] = "준비됨",
		["Button.Max"] = "최대",
		["Button.Roll"] = "굴리기",
		["Button.GainIQ"] = "IQ 얻기",
		["Button.AutoLocked"] = "자동\n잠김",
		["Button.AutoOn"] = "자동 켜짐",
		["Button.AutoOff"] = "자동 꺼짐",
		["Action.Claim"] = "받기",
		["Action.Claimed"] = "받음",
		["Action.OpenBasic"] = "기본 열기",
		["Action.Need"] = "필요",
		["Action.Locked"] = "잠김",
		["Unit.Wins"] = "승리",
		["Unit.CP"] = "CP",
		["Stat.IQ"] = "IQ",
		["Stat.Wins"] = "승리",
		["Stat.Luck"] = "운",
		["Stat.LuckLevel"] = "운 레벨",
		["Stat.AutoLevel"] = "자동 레벨",
		["Stat.KP"] = "KP",
		["Panel.Index.Title"] = "개념 도감",
		["Panel.Index.Total"] = "총 발견",
		["Panel.Index.Level"] = "도감 레벨",
		["Panel.Index.KPIQBonus"] = "KP IQ 보너스",
		["Panel.Index.MilestoneBonus"] = "도감 보상 보너스",
		["Panel.Index.NextReward"] = "다음 보상",
		["Panel.Index.Recent"] = "최근",
		["Panel.Index.NoDiscoveries"] = "아직 발견 없음",
		["Panel.Quest.Title"] = "퀘스트",
		["Panel.Quest.Progress"] = "진행도",
		["Panel.Quest.Reward"] = "보상",
		["Panel.Chest.Title"] = "상자",
		["Panel.Chest.Basic"] = "기본 상자",
		["Panel.Chest.Points"] = "상자 포인트",
		["Panel.Chest.OpenedSession"] = "이번 세션에서 연 상자",
		["Panel.Chest.Cost"] = "비용",
		["Popup.NewConcept"] = "새 개념",
		["Popup.IndexBonus"] = "도감 보너스",
		["Popup.QuestClaimed"] = "퀘스트 보상 받음",
		["Popup.ChestOpened"] = "상자 열림",
		["Popup.ChestPoints"] = "상자 포인트",
		["Roulette.Rolling"] = "굴리는 중",
		["Tutorial.StartRolling.Title"] = "굴리기 시작",
		["Tutorial.StartRolling.Body"] = "굴리기를 눌러 IQ를 얻고 두뇌 개념을 발견하세요.",
		["Tutorial.IQGained.Title"] = "IQ 획득",
		["Tutorial.IQGained.Body"] = "IQ는 성장을 빠르게 하고 다음 목표에 도달하게 해줍니다.",
		["Tutorial.ConceptIndex.Title"] = "개념 도감",
		["Tutorial.ConceptIndex.Body"] = "새 개념은 도감에 저장됩니다. 더 많이 발견하면 성장 보너스를 얻습니다.",
		["Tutorial.LuckUpgrade.Title"] = "운 업그레이드",
		["Tutorial.LuckUpgrade.Body"] = "승리를 사용해 운을 강화하세요. 운이 높을수록 희귀 개념을 찾기 쉽습니다.",
		["Tutorial.AutoRoll.Title"] = "자동 굴리기",
		["Tutorial.AutoRoll.Body"] = "자동 굴리기를 해금하면 계속 굴릴 수 있습니다.",
		["Tutorial.Goal.Title"] = "목표",
		["Tutorial.Goal.Body"] = "IQ를 키우고, 승리를 얻고, 도감을 채우며 희귀 개념을 찾아보세요.",
		["Tutorial.Next"] = "다음",
		["Tutorial.Finish"] = "완료",
		["Tutorial.Skip"] = "건너뛰기",
		["Quest.Roll50.Title"] = "50번 굴리기",
		["Quest.Roll50.Description"] = "50번 굴리세요.",
		["Quest.Gain1000IQ.Title"] = "IQ 1,000 얻기",
		["Quest.Gain1000IQ.Description"] = "굴리기로 IQ 1,000을 얻으세요.",
		["Quest.Discover3.Title"] = "개념 3개 발견",
		["Quest.Discover3.Description"] = "새 개념 3개를 발견하세요.",
	},
}

local conceptPhrases = {
	ko = {
		["Absolute Mind"] = "절대 지성",
		["Beyond Dimension"] = "차원 너머",
		["Black Hole"] = "블랙홀",
		["Cosmic Core"] = "우주 핵",
		["Grand Genius"] = "대천재",
		["Harvard Level"] = "하버드급",
		["Hyper Focused"] = "초집중",
		["Top Rank"] = "전국 1등",
		["Ultra Fast"] = "초고속",
		["Ultra Precise"] = "초정밀",
		["AI"] = "AI",
		["Admin"] = "관리자",
		["Algorithm"] = "알고리즘",
		["Alpha"] = "알파",
		["Analysis"] = "분석",
		["Answer"] = "해답",
		["Applied"] = "응용",
		["Astronomy"] = "천문학",
		["Basic"] = "기초",
		["Beginner"] = "초보",
		["Biology"] = "생명",
		["Brain"] = "두뇌",
		["Breakthrough"] = "돌파",
		["Calculation"] = "계산",
		["Calculated"] = "계산된",
		["Calm"] = "차분한",
		["Chemistry"] = "화학",
		["Circuit"] = "회로",
		["Clear"] = "선명한",
		["Clever"] = "똑똑한",
		["Coding"] = "코딩",
		["Core"] = "코어",
		["Cosmic"] = "우주급",
		["Da Vinci"] = "다빈치",
		["Dimension"] = "차원",
		["Dimensional"] = "차원급",
		["Discovery"] = "발견",
		["Divine"] = "신의",
		["Dominant"] = "압도적",
		["Drowsy"] = "졸린",
		["Einstein"] = "아인슈타인",
		["Engine"] = "엔진",
		["Experiment"] = "실험",
		["Extreme"] = "극한",
		["Faint"] = "흐릿한",
		["Focused"] = "집중한",
		["Forbidden"] = "금지된",
		["Formula"] = "공식",
		["Genius"] = "천재적",
		["Golden"] = "황금",
		["Hawking"] = "호킹",
		["Hidden"] = "숨겨진",
		["Infinite"] = "무한",
		["Insight"] = "통찰",
		["Intelligence"] = "지능",
		["Language"] = "언어",
		["Legendary"] = "전설의",
		["Logic"] = "논리",
		["Logical"] = "논리적",
		["Map"] = "지도",
		["Master"] = "마스터",
		["Math"] = "수학",
		["Memory"] = "기억",
		["Mind"] = "지성",
		["Module"] = "모듈",
		["Mythic"] = "신화적",
		["Newton"] = "뉴턴",
		["Note"] = "노트",
		["Old"] = "낡은",
		["Olympiad"] = "올림피아드",
		["Operation"] = "연산",
		["Paper"] = "논문",
		["Pattern"] = "패턴",
		["Perfect"] = "완벽한",
		["Physics"] = "물리",
		["Plain"] = "평범한",
		["Precise"] = "정확한",
		["Proof"] = "증명",
		["Puzzle"] = "퍼즐",
		["Quick"] = "빠른",
		["Quiet"] = "조용한",
		["Quiz"] = "퀴즈",
		["Reasoning"] = "추론",
		["Record"] = "기록",
		["Research"] = "연구",
		["Robotics"] = "로봇",
		["Routine"] = "루틴",
		["Science"] = "과학",
		["Secret"] = "비밀",
		["Sense"] = "감각",
		["Sharp"] = "영리한",
		["Slow"] = "느린",
		["Spark"] = "스파크",
		["Strategy"] = "전략",
		["Tesla"] = "테슬라",
		["Thinking"] = "사고력",
		["Timebreaking"] = "시간초월",
		["Tiny"] = "작은",
		["Training"] = "훈련",
		["Transcendent"] = "초월",
		["Void"] = "공허",
	},
}

local sortedConceptPhrasesByLocale = {}

local function normalizeLocale(locale)
	locale = string.lower(tostring(locale or DEFAULT_LOCALE))

	if string.sub(locale, 1, 2) == "ko" then
		return "ko"
	end

	return DEFAULT_LOCALE
end

local function getSortedConceptPhrases(locale)
	locale = normalizeLocale(locale)

	if sortedConceptPhrasesByLocale[locale] then
		return sortedConceptPhrasesByLocale[locale]
	end

	local list = {}
	for phrase, translated in pairs(conceptPhrases[locale] or {}) do
		table.insert(list, {
			Source = phrase,
			Translated = translated,
		})
	end

	table.sort(list, function(left, right)
		if #left.Source == #right.Source then
			return left.Source < right.Source
		end

		return #left.Source > #right.Source
	end)

	sortedConceptPhrasesByLocale[locale] = list
	return list
end

function LocalizationText.GetLocale(playerOrNil)
	local playerLocale = nil

	if playerOrNil and typeof(playerOrNil) == "Instance" then
		pcall(function()
			playerLocale = playerOrNil.LocaleId
		end)
	end

	if not playerLocale or playerLocale == "" then
		pcall(function()
			playerLocale = LocalizationService.RobloxLocaleId
		end)
	end

	if not playerLocale or playerLocale == "" then
		pcall(function()
			playerLocale = LocalizationService.SystemLocaleId
		end)
	end

	return normalizeLocale(playerLocale)
end

function LocalizationText.T(key, fallbackText, locale)
	locale = normalizeLocale(locale)
	key = tostring(key or "")

	local localeTable = translations[locale]
	if localeTable and localeTable[key] then
		return localeTable[key]
	end

	return tostring(fallbackText or key)
end

function LocalizationText.TranslateConceptName(conceptName, locale)
	locale = normalizeLocale(locale)
	conceptName = tostring(conceptName or "")

	if locale == DEFAULT_LOCALE or conceptName == "" then
		return conceptName
	end

	local translatedWords = {}
	local words = {}
	for word in string.gmatch(conceptName, "%S+") do
		table.insert(words, word)
	end

	local phrases = getSortedConceptPhrases(locale)
	local index = 1

	while index <= #words do
		local matchedPhrase = nil
		local matchedWordCount = 0

		for _, phrase in ipairs(phrases) do
			local phraseWords = {}
			for word in string.gmatch(phrase.Source, "%S+") do
				table.insert(phraseWords, word)
			end

			if #phraseWords > 0 and index + #phraseWords - 1 <= #words then
				local matches = true

				for phraseIndex, phraseWord in ipairs(phraseWords) do
					if words[index + phraseIndex - 1] ~= phraseWord then
						matches = false
						break
					end
				end

				if matches then
					matchedPhrase = phrase.Translated
					matchedWordCount = #phraseWords
					break
				end
			end
		end

		if matchedPhrase then
			table.insert(translatedWords, matchedPhrase)
			index += matchedWordCount
		else
			table.insert(translatedWords, words[index])
			index += 1
		end
	end

	return table.concat(translatedWords, " ")
end

return LocalizationText
