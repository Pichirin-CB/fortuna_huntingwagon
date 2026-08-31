-- =======================================================================================
-- =====  ██████╗ ██████╗     ███████╗████████╗██╗   ██╗██████╗ ██╗ ██████╗ ███████╗ =====
-- ===== ██╔════╝ ██╔══██╗    ██╔════╝╚══██╔══╝██║   ██║██╔══██╗██║██╔═══██╗██╔════╝ =====
-- ===== ██║      ██████╔╝    ███████╗   ██║   ██║   ██║██║  ██║██║██║   ██║███████╗ =====
-- ===== ██║      ██╔══██╗    ╚════██║   ██║   ██║   ██║██║  ██║██║██║   ██║╚════██║ =====
-- ===== ╚██████╗ ██████╔╝    ███████║   ██║   ╚██████╔╝██████╔╝██║╚██████╔╝███████║ =====
-- =====  ╚═════╝ ╚═════╝     ╚══════╝   ╚═╝    ╚═════╝ ╚═════╝ ╚═╝ ╚═════╝ ╚══════╝ =====
-- =======================================================================================
-- =====               CB │ STUDIOS - FORTUNA HUNTING WAGON                       =====
-- =====               DISCORD: https://discord.gg/hsx6AvBg5s                     =====
-- =======================================================================================

Config = {}

-- ============================================================================
-- CORE
-- ============================================================================
Config.Locale = "es" -- en / pt / fr / de / es / ro
Config.Debug = false

Config.Project = {
    Name = "CB Studios",
    Documentation = "https://docs.pichirincb.com/#/",
    Discord = "https://discord.gg/hsx6AvBg5s"
}

-- ============================================================================
-- HUNTING WAGON
-- ============================================================================
-- Native Red Dead Redemption 2 hunting wagon used by this resource.
Config.WagonModel = `huntercart01`

-- Maximum total cargo capacity.
-- Cargo consumes 1 to 4 units according to physical volume and carry form.
-- Pelts use 1 (under-arm/rolled), 2 (flat/large) or 3 (extra-large) units.
-- Animal carcasses use 1 to 4 units from tiny to extra-large.
Config.MaxCapacity = 14

-- ============================================================================
-- INTERACTION
-- ============================================================================
-- Maximum distance at which the player can interact with the rear of the wagon.
Config.InteractionDistance = 1.65

-- Server-side distance validation between player and wagon.
Config.PlayerValidationDistance = 2.75

-- Server-side distance validation between cargo and wagon.
Config.CargoValidationDistance = 3.25

-- Maximum distance for detecting supported cargo directly on the ground.
Config.GroundCargoDistance = 2.0

-- Default interaction control.
Config.Control = 0xE30CD707 -- R

-- ============================================================================
-- SECURITY / VALIDATION
-- ============================================================================
-- Maximum time allowed for the client to confirm deletion of stored cargo.
Config.DeleteConfirmationTimeout = 2500

-- Maximum time a pending retrieval remains active before recovery.
Config.RetrieveTimeout = 12

-- Interval used by internal maintenance/recovery routines.
Config.MaintenanceInterval = 1000

-- ============================================================================
-- NOTIFICATIONS
-- ============================================================================
-- auto:
--   Uses VORP notifications when available.
--   Otherwise falls back to standard chat or console output.
--
-- Available:
--   auto / vorp / chat / custom
Config.Notification = {
    System = "auto",
    CustomEvent = ""
}

-- ============================================================================
-- ACCESS CONTROL
-- ============================================================================
-- public:
--   Every player may use every hunting wagon.
--
-- ace:
--   Requires Config.Access.AcePermission.
--
-- statebag:
--   Compares Config.Access.OwnerStateBag against the player's server ID
--   or one of the player's identifiers.
--
-- CustomCheck:
--   Optional server-side function that can override the selected access mode.
Config.Access = {
    Mode = "public",
    AcePermission = "fortuna_huntingwagon.use",
    OwnerStateBag = "owner",
    CustomCheck = nil
}

-- ============================================================================
-- OPTIONAL DATABASE PERSISTENCE
-- ============================================================================
-- Disabled keeps the original standalone, session-only behaviour.
-- To enable: import INSTALL_FILES/fortuna_huntingwagon.sql, keep oxmysql and
-- vorp_stables started before this resource, then set Enabled = true.
Config.Persistence = {
    Enabled = false,
    Adapter = "vorp_stables",
    StateBagKey = "fortunaStableWagonId",
    Table = "fortuna_huntingwagon_cargo",
    RequireRegisteredWagon = true
}

-- ============================================================================
-- DISCORD LOGS
-- ============================================================================
Config.Discord = {
    Enabled = false,

    -- Keep this empty in public repositories.
    -- Recommended server.cfg configuration:
    --
    -- set fortuna_huntingwagon_webhook "YOUR_PRIVATE_WEBHOOK"
    Webhook = "",

    BotName = "Fortuna Hunting Wagon",
    AvatarUrl = "",
    FooterIconUrl = "",

    -- Optional role mention for security warnings.
    MentionOnSecurityWarning = "",

    -- Log categories.
    LogStore = true,
    LogRetrieve = true,
    LogSecurityWarnings = true,

    -- Internal Discord log queue.
    QueueLimit = 200,
    MaxRetries = 3,
    DelayBetweenMessages = 300,

    -- Discord embed colors.
    Colors = {
        store = 5763719,
        retrieve = 3447003,
        security = 15548997
    }
}

-- ============================================================================
-- VISUAL CARGO SYSTEM
-- ============================================================================
-- Native huntercart01 tarp prop set.
-- The tarp visually represents occupied wagon capacity.
Config.VisualTarpPropSet = `PG_MP005_HUNTINGWAGONTARP01`

-- Maximum distance at which the visual tarp state is maintained.
Config.VisualDistance = 65.0

-- ============================================================================
-- CARGO
-- ============================================================================
-- Cargo values represent how much capacity each model consumes.
--
-- Size 1:
--   Tiny carcasses and under-arm/rolled pelts.
--
-- Size 2:
--   Medium carcasses and flat/large pelts.
--
-- Size 3:
--   Large carcasses and extra-large pelts.
--
-- Size 4:
--   Extra-large animal carcasses.
--
-- Example:
--
-- Config.Cargo[`a_c_example_01`] = 2
--
-- With Config.MaxCapacity = 14:
--   14 x size-1 cargo
--    7 x size-2 cargo
--    4 x size-3 cargo (2 capacity units remain)
--    3 x size-4 cargo (2 capacity units remain)
--   or any combination up to 14 total capacity units.

Config.Cargo = {

    -- ========================================================================
    -- ALLIGATORS
    -- ========================================================================
    [`a_c_alligator_01`] = 4,
    [`a_c_alligator_02`] = 3,
    [`a_c_alligator_03`] = 3,

    -- ========================================================================
    -- SMALL GAME
    -- ========================================================================
    [`a_c_armadillo_01`] = 1,
    [`a_c_badger_01`] = 1,
    [`a_c_beaver_01`] = 2,
    [`a_c_fox_01`] = 2,
    [`a_c_goat_01`] = 3,
    [`a_c_javelina_01`] = 3,
    [`a_c_muskrat_01`] = 1,
    [`a_c_possum_01`] = 1,
    [`a_c_rabbit_01`] = 1,
    [`a_c_raccoon_01`] = 1,
    [`a_c_sheep_01`] = 3,
    [`a_c_skunk_01`] = 1,
    [`a_c_turkeywild_01`] = 2,
    [`a_c_vulture_01`] = 2,

    -- ========================================================================
    -- PREDATORS
    -- ========================================================================
    [`a_c_bearblack_01`] = 3,
    [`a_c_bear_01`] = 4,
    [`a_c_cougar_01`] = 3,
    [`a_c_panther_01`] = 3,
    [`a_c_wolf`] = 3,
    [`a_c_wolf_medium`] = 3,
    [`a_c_wolf_small`] = 2,

    -- ========================================================================
    -- DEER / LARGE WILDLIFE
    -- ========================================================================
    [`a_c_bighornram_01`] = 3,
    [`a_c_boar_01`] = 3,
    [`a_c_buck_01`] = 3,
    [`a_c_buffalo_01`] = 4,
    [`a_c_coyote_01`] = 2,
    [`a_c_deer_01`] = 3,
    [`a_c_elk_01`] = 4,
    [`a_c_moose_01`] = 4,
    [`a_c_pronghorn_01`] = 3,

    -- ========================================================================
    -- FARM / DOMESTIC ANIMALS
    -- ========================================================================
    [`a_c_bull_01`] = 4,
    [`a_c_cow`] = 4,
    [`a_c_ox_01`] = 4,
    [`a_c_pig_01`] = 3,

    -- ========================================================================
    -- SMALL / MEDIUM PELTS
    -- ========================================================================
    [`p_cs_pelt_med_armadillo`] = 1,
    [`p_cs_pelt_med_badger`] = 1,
    [`p_cs_pelt_med_muskrat`] = 1,
    [`p_cs_pelt_med_possum`] = 1,
    [`p_cs_pelt_med_raccoon`] = 1,
    [`p_cs_pelt_med_skunk`] = 1,
    [`p_cs_rabbitskin_flat`] = 1,
    [`p_cs_iguanapelt`] = 1,
    [`p_cs_iguanapelt02x`] = 1,
    [`p_cs_gilamonsterpelt01x`] = 1,
    [`p_cs_pelt_medium`] = 1,
    [`p_cs_pelt_medium_og`] = 1,
    [`p_cs_crocskin_medium_flat`] = 2,
    [`p_cs_crocskin_medium_roll`] = 1,
    [`p_cs_cyteskin_medium_flat`] = 2,
    [`p_cs_deerskin_medium_flat`] = 2,
    [`p_cs_blackbearskin_medlarge`] = 2,
    [`p_cs_pelt_medlarge`] = 2,
    [`p_cs_pelt_medlarge_roll`] = 1,
    [`p_cs_pelt_wolf`] = 2,
    [`p_cs_pelt_wolf_roll`] = 1,

    -- ========================================================================
    -- LARGE PELTS
    -- ========================================================================
    [`p_cs_alligatorpelt_large`] = 2,
    [`p_cs_pelt_large`] = 2,
    [`p_cs_wolfpelt_large`] = 2,
    [`p_cs_pelt_elklegendary`] = 3,
    [`p_cs_bearskin_xlarge_roll`] = 2,
    [`p_cs_bfloskin_xlarge_roll`] = 2,
    [`p_cs_bullgator_xlarge_roll`] = 2,
    [`p_cs_cowpelt2_xlarge`] = 3,
    [`p_cs_pelt_xlarge`] = 3,
    [`p_cs_pelt_xlarge_alligator`] = 3,
    [`p_cs_pelt_xlarge_bear`] = 3,
    [`p_cs_pelt_xlarge_bearlegendary`] = 3,
    [`p_cs_pelt_xlarge_buffalo`] = 3,
    [`p_cs_pelt_xlarge_elk`] = 3,
    [`p_cs_pelt_xlarge_tbuffalo`] = 3,
    [`p_cs_pelt_xlarge_wbuffalo`] = 3
}
