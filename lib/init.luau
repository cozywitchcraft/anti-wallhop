--!strict
type AntiWallhopImpl = {
	__index: AntiWallhopImpl,
	new: (character: Model) -> AntiWallhop,
	isGrounded: (self: AntiWallhop) -> boolean,
	onPostSimulation: (self: AntiWallhop) -> (),
	enable: (self: AntiWallhop) -> (),
	disable: (self: AntiWallhop) -> (),
	drawLine: (self: AntiWallhop, origin: Vector3, direction: Vector3, result: RaycastResult?) -> (),
	resetLines: (self: AntiWallhop) -> (),
	enableDebug: (self: AntiWallhop) -> (),
	disableDebug: (self: AntiWallhop) -> (),
	destroy: (self: AntiWallhop) -> (),
}

type AntiWallhop = typeof(setmetatable({} :: {
	character: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
	params: RaycastParams,
	isRigTypeR6: boolean,
	postSimulationConnection: RBXScriptConnection?,
	collisionGroupChangedConnection: RBXScriptConnection?,
	debugEnabled: boolean,
	lines: { LineHandleAdornment },
	lineIndex: number,
}, {} :: AntiWallhopImpl))

local RunService = game:GetService("RunService")

local CAST_POINTS: { Vector3 } = {
	-- Center line
	Vector3.new(0, -0.75, 0),
	Vector3.new(0, -0.75, 1),
	Vector3.new(0, -0.75, -1),

	-- Corners
	Vector3.new(-1, -0.75, -1),
	Vector3.new(-1, -0.75, 1),
	Vector3.new(1, -0.75, -1),
	Vector3.new(1, -0.75, 1),
}

local AntiWallhop = {} :: AntiWallhopImpl
AntiWallhop.__index = AntiWallhop

function AntiWallhop.new(character: Model): AntiWallhop
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	assert(humanoid, "Cannot find Humanoid")

	local rootPart = humanoid.RootPart
	assert(rootPart, "Cannot find HumanoidRootPart")

	-- Saves an __index call per frame
	local isRigTypeR6 = humanoid.RigType == Enum.HumanoidRigType.R6

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.CollisionGroup = rootPart.CollisionGroup
	params.RespectCanCollide = true
	params.IgnoreWater = true

	-- Support collision groups (e.g. player-to-player non-collision)
	local collisionGroupChangedConnection = rootPart:GetPropertyChangedSignal("CollisionGroup"):Connect(function()
		params.CollisionGroup = rootPart.CollisionGroup
	end)

	return setmetatable({
		character = character,
		humanoid = humanoid,
		rootPart = rootPart,
		isRigTypeR6 = isRigTypeR6,
		params = params,
		collisionGroupChangedConnection = collisionGroupChangedConnection,
		debugEnabled = false,
		lines = {},
		lineIndex = 0,
	}, AntiWallhop)
end

function AntiWallhop:isGrounded(): boolean
	local cframe = self.rootPart.CFrame
	local halfSize = 0.4 * self.rootPart.Size -- 0.1-stud skin

	local verticalVelocity = self.rootPart.AssemblyLinearVelocity.Y

	-- Floor detection uses an initial factor of 1.2 when grounded and 1.5 when
	-- falling. Since we're only concerned with floor detection when falling,
	-- the factor starts at 1.5.
	local factor = 1.5
	local minVelocity = -125 * halfSize.Y

	if verticalVelocity > 0 then
		return false -- Prevents double jumping
	elseif verticalVelocity < minVelocity then
		factor += verticalVelocity / minVelocity -- Prevents bouncing
	end

	local hipHeight = 0.6 * halfSize.Y + self.humanoid.HipHeight

	-- R15 only relies on the hip height while R6 takes legs into consideration
	if self.isRigTypeR6 then
		local legHeight = 0

		local leftLeg = self.character:FindFirstChild("Left Leg")
		local rightLeg = self.character:FindFirstChild("Right Leg")

		if leftLeg and leftLeg:IsA("BasePart") then
			legHeight = math.max(legHeight, leftLeg.Size.Y)
		end

		if rightLeg and rightLeg:IsA("BasePart") then
			legHeight = math.max(legHeight, rightLeg.Size.Y)
		end

		hipHeight += legHeight
	end

	local direction = hipHeight * factor * -Vector3.yAxis

	self:resetLines()

	for _, point in CAST_POINTS do
		local origin = cframe:PointToWorldSpace(halfSize * point)
		local result = workspace:Raycast(origin, direction, self.params)

		self:drawLine(origin, direction, result)

		if result then
			return true
		end
	end

	return false
end

function AntiWallhop:onPostSimulation()
	debug.profilebegin("AntiWallhop::onPostSimulation")

	local isFalling = self.humanoid:GetState() == Enum.HumanoidStateType.Freefall

	-- We're only worried about detecting the floor while the humanoid is falling.
	-- This is because wallhopping only occurs when entering the landing state pre-
	-- simulation, so we move it post-simulation.
	if isFalling and self:isGrounded() then
		self.humanoid:ChangeState(Enum.HumanoidStateType.Landed)
	end

	debug.profileend()
end

function AntiWallhop:enable()
	if self.postSimulationConnection then
		return
	end

	-- Disable humanoid's built-in floor detection
	self.humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, false)

	-- Start custom floor detection after physics simulation
	self.postSimulationConnection = RunService.PostSimulation:Connect(function()
		self:onPostSimulation()
	end)
end

function AntiWallhop:disable()
	if not self.postSimulationConnection then
		return
	end

	self.humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, true)

	self.postSimulationConnection = self.postSimulationConnection:Disconnect()
end

function AntiWallhop:drawLine(origin: Vector3, direction: Vector3, result: RaycastResult?)
	if not self.debugEnabled then
		return
	end

	self.lineIndex += 1

	local color = Color3.new(result and 0 or 1, result and 1 or 0, 0)

	local line = self.lines[self.lineIndex]
	line.CFrame = CFrame.new(origin, origin + direction)
	line.Length = direction.Magnitude
	line.Thickness = 3
	line.Color3 = color
	line.Visible = true
end

function AntiWallhop:resetLines()
	if not self.debugEnabled then
		return
	end

	self.lineIndex = 0

	for _, line in self.lines do
		line.Visible = false
	end
end

function AntiWallhop:enableDebug()
	if self.debugEnabled then
		return
	end

	for _ = 1, #CAST_POINTS do
		local line = Instance.new("LineHandleAdornment")
		line.Thickness = 3
		line.Visible = false
		line.Adornee = workspace.Terrain

		-- Lines are removed when character is removed
		line.Parent = self.character

		table.insert(self.lines, line)
	end

	self.debugEnabled = true
end

function AntiWallhop:disableDebug()
	if not self.debugEnabled then
		return
	end

	for _, line in self.lines do
		line:Destroy()
	end

	table.clear(self.lines)

	self.debugEnabled = false
end

-- https://devforum.roblox.com/t/new-player-and-character-destroy-behavior/2711317/79
function AntiWallhop:destroy()
	self:disable()
	self:disableDebug()

	if self.collisionGroupChangedConnection then
		self.collisionGroupChangedConnection = self.collisionGroupChangedConnection:Disconnect()
	end
end

return AntiWallhop
