return {
    {
        "3rd/image.nvim",
        event = "VeryLazy",
        build = false,
        opts = {
            backend = "kitty",
            processor = "magick_cli",
            kitty_method = "normal",
            integrations = {
                asciidoc = {
                    enabled = false,
                },
                markdown = {
                    enabled = true,
                    clear_in_insert_mode = false,
                    download_remote_images = false,
                    only_render_image_at_cursor = false,
                    only_render_image_at_cursor_mode = "inline",
                    filetypes = { "markdown", "vimwiki" },
                },
                rst = {
                    enabled = true,
                    clear_in_insert_mode = false,
                    download_remote_images = false,
                    only_render_image_at_cursor = false,
                    only_render_image_at_cursor_mode = "inline",
                },
                typst = {
                    enabled = true,
                    clear_in_insert_mode = false,
                    download_remote_images = false,
                    only_render_image_at_cursor = false,
                    only_render_image_at_cursor_mode = "inline",
                },
                neorg = {
                    enabled = false,
                },
                syslang = {
                    enabled = false,
                },
            },
        },
    },
}
