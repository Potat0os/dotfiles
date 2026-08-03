return {
    {
        "williamboman/mason.nvim",
        config = function()
            require("mason").setup()
        end
    },
    {
        "williamboman/mason-lspconfig.nvim",
        config = function()
            require("mason-lspconfig").setup({
                ensure_installed = {"lua_ls", "clangd", "cmake", "cssls", "html"}
            })
        end
    },
    {
        "neovim/nvim-lspconfig",
        config = function()
            -- New API (Neovim 0.11+): configure and enable servers directly,
            -- instead of the old require('lspconfig').<server>.setup{} pattern.
            local servers = {"lua_ls", "clangd", "cmake", "cssls", "html"}

            for _, server in ipairs(servers) do
                vim.lsp.config(server, {})
            end

            vim.lsp.enable(servers)

            vim.keymap.set('n', 'K', vim.lsp.buf.hover, {})
        end
    }
}
