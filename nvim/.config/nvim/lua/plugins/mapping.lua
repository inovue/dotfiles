return {
  {
    "AstroNvim/astrocore",
    ---@type AstroCoreOpts
    opts = {
      mappings = {
        -- first key is the mode
        n = {
          -- ["<Leader>bn"] = { "<cmd>tabnew<cr>", desc = "New tab" },

          ["<leader>ghh"] = {
            function()
              local actions = require "CopilotChat.actions"
              require("CopilotChat.integrations.telescope").pick(actions.help_actions())
            end,
            desc = "CopilotChat - Help actions",
          },
          -- Show prompts actions with telescope
          ["<leader>gha"] = {
            function()
              local actions = require "CopilotChat.actions"
              require("CopilotChat.integrations.telescope").pick(actions.prompt_actions())
            end,
            desc = "CopilotChat - Prompt actions",
          },
        },
      },
    },
  },
}
