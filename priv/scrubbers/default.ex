defmodule Pleroma.HTML.Scrubber.Default do
  @doc "The default HTML scrubbing policy: no "

  require FastSanitize.Sanitizer.Meta
  alias FastSanitize.Sanitizer.Meta

  # credo:disable-for-previous-line
  # No idea how to fix this one…

  @valid_schemes Pleroma.Config.get([:uri_schemes, :valid_schemes], [])

  Meta.strip_comments()

  Meta.allow_tag_with_uri_attributes(:a, ["href", "data-user", "data-tag"], @valid_schemes)

  Meta.allow_tag_with_this_attribute_values(:a, "class", [
    "hashtag",
    "u-url",
    "mention",
    "u-url mention",
    "mention u-url"
  ])

  Meta.allow_tag_with_this_attribute_values(:a, "rel", [
    "tag",
    "nofollow",
    "noopener",
    "noreferrer",
    "ugc",
    "tag ugc",
    "ugc tag"
  ])

  Meta.allow_tag_with_these_attributes(:a, ["name", "title"])

  Meta.allow_tag_with_these_attributes(:abbr, ["title"])

  Meta.allow_tag_with_these_attributes(:b, [])
  Meta.allow_tag_with_these_attributes(:blockquote, [])
  Meta.allow_tag_with_these_attributes(:br, [])
  Meta.allow_tag_with_these_attributes(:code, [])
  Meta.allow_tag_with_these_attributes(:del, [])
  Meta.allow_tag_with_these_attributes(:em, [])
  Meta.allow_tag_with_these_attributes(:hr, [])
  Meta.allow_tag_with_these_attributes(:i, [])
  Meta.allow_tag_with_these_attributes(:li, [])
  Meta.allow_tag_with_these_attributes(:ol, [])
  Meta.allow_tag_with_these_attributes(:p, [])
  Meta.allow_tag_with_these_attributes(:pre, [])
  Meta.allow_tag_with_these_attributes(:strong, [])
  Meta.allow_tag_with_these_attributes(:sub, [])
  Meta.allow_tag_with_these_attributes(:sup, [])
  Meta.allow_tag_with_these_attributes(:ruby, [])
  Meta.allow_tag_with_these_attributes(:rb, [])
  Meta.allow_tag_with_these_attributes(:rp, [])
  Meta.allow_tag_with_these_attributes(:rt, [])
  Meta.allow_tag_with_these_attributes(:rtc, [])
  Meta.allow_tag_with_these_attributes(:u, [])
  Meta.allow_tag_with_these_attributes(:ul, [])

  Meta.allow_tag_with_this_attribute_values(:span, "class", [
    "h-card",
    "quote-inline",
    # "FEP-c16b: Formatting MFM functions" tags that Akkoma supports
    # NOTE: Maybe it would be better to have something like "allow `mfm-*`,
    #       but at moment of writing this is not a thing in the HTML parser we use
    # The following are the non-animated MFM
    "mfm-center",
    "mfm-flip",
    "mfm-font",
    "mfm-blur",
    "mfm-rotate",
    "mfm-x2",
    "mfm-x3",
    "mfm-x4",
    "mfm-position",
    "mfm-scale",
    "mfm-fg",
    "mfm-bg",
    # The following are the animated MFM
    "mfm-jelly",
    "mfm-twitch",
    "mfm-shake",
    "mfm-spin",
    "mfm-jump",
    "mfm-bounce",
    "mfm-rainbow",
    "mfm-tada",
    "mfm-sparkle",
    # MFM legacy
    # This is for backwards compatibility with posts formatted on Akkoma before support for FEP-c16b
    "mfm",
    "mfm _mfm_tada_",
    "mfm _mfm_jelly_",
    "mfm _mfm_twitch_",
    "mfm _mfm_shake_",
    "mfm _mfm_spin_",
    "mfm _mfm_jump_",
    "mfm _mfm_bounce_",
    "mfm _mfm_flip_",
    "mfm _mfm_x2_",
    "mfm _mfm_x3_",
    "mfm _mfm_x4_",
    "mfm _mfm_blur_",
    "mfm _mfm_rainbow_",
    "mfm _mfm_rotate_"
  ])

  Meta.allow_tag_with_these_attributes(:span, [
    # "FEP-c16b: Formatting MFM functions" attributes that Akkoma supports
    # NOTE: Maybe it would be better to have something like "allow `data-mfm-*`,
    #       but at moment of writing this is not a thing in the HTML parser we use
    "data-mfm-h",
    "data-mfm-v",
    "data-mfm-x",
    "data-mfm-y",
    "data-mfm-alternate",
    "data-mfm-speed",
    "data-mfm-deg",
    "data-mfm-left",
    "data-mfm-serif",
    "data-mfm-monospace",
    "data-mfm-cursive",
    "data-mfm-fantasy",
    "data-mfm-emoji",
    "data-mfm-math",
    "data-mfm-color",
    # MFM legacy
    # This is for backwards compatibility with posts formatted on Akkoma before support for FEP-c16b
    "data-x",
    "data-y",
    "data-h",
    "data-v",
    "data-left",
    "data-right"
  ])

  Meta.allow_tag_with_this_attribute_values(:code, "class", ["inline"])

  @allow_inline_images Pleroma.Config.get([:markup, :allow_inline_images])

  if @allow_inline_images do
    # restrict img tags to http/https only, because of MediaProxy.
    Meta.allow_tag_with_uri_attributes(:img, ["src"], ["http", "https"])

    Meta.allow_tag_with_these_attributes(:img, [
      "width",
      "height",
      "title",
      "alt"
    ])
  end

  if Pleroma.Config.get([:markup, :allow_tables]) do
    Meta.allow_tag_with_these_attributes(:table, [])
    Meta.allow_tag_with_these_attributes(:tbody, [])
    Meta.allow_tag_with_these_attributes(:td, [])
    Meta.allow_tag_with_these_attributes(:th, [])
    Meta.allow_tag_with_these_attributes(:thead, [])
    Meta.allow_tag_with_these_attributes(:tr, [])
  end

  if Pleroma.Config.get([:markup, :allow_headings]) do
    Meta.allow_tag_with_these_attributes(:h1, [])
    Meta.allow_tag_with_these_attributes(:h2, [])
    Meta.allow_tag_with_these_attributes(:h3, [])
    Meta.allow_tag_with_these_attributes(:h4, [])
    Meta.allow_tag_with_these_attributes(:h5, [])
  end

  if Pleroma.Config.get([:markup, :allow_fonts]) do
    Meta.allow_tag_with_these_attributes(:font, ["face"])
  end

  if Pleroma.Config.get!([:markup, :allow_math]) do
    Meta.allow_tag_with_these_attributes("annotation", ["encoding"])
    Meta.allow_tag_with_these_attributes(:"annotation-xml", ["encoding"])

    Meta.allow_tag_with_these_attributes(:math, [
      "display",
      "displaystyle",
      "mathvariant",
      "scriptlevel"
    ])

    basic_math_tags = [
      "maction",
      "merror",
      :mi,
      "mmultiscripts",
      :mn,
      "mphantom",
      "mprescripts",
      "mroot",
      "mrow",
      "ms",
      "msqrt",
      "mstyle",
      "msub",
      "msubsup",
      "msup",
      "mtable",
      "mtext",
      "mtr",
      "semantics"
    ]

    for tag <- basic_math_tags do
      Meta.allow_tag_with_these_attributes(unquote(tag), [
        "mathvariant",
        "displaystyle",
        "scriptlevel"
      ])
    end

    Meta.allow_tag_with_these_attributes("mfrac", [
      "displaystyle",
      "linethickness",
      "mathvariant",
      "scriptlevel"
    ])

    Meta.allow_tag_with_these_attributes(:mo, [
      "displaystyle",
      "form",
      "largeop",
      "lspace",
      "mathvariant",
      "minsize",
      "movablelimits",
      "rspace",
      "scriptlevel",
      "stretchy",
      "symmetric"
    ])

    Meta.allow_tag_with_these_attributes("mover", [
      "accent",
      "displaystyle",
      "mathvariant",
      "scriptlevel"
    ])

    Meta.allow_tag_with_these_attributes("mpadded", [
      "depth",
      "displaystyle",
      "height",
      "lspace",
      "mathvariant",
      "scriptlevel",
      "voffset",
      "width"
    ])

    Meta.allow_tag_with_these_attributes("mspace", [
      "depth",
      "displaystyle",
      "height",
      "mathvariant",
      "scriptlevel",
      "width"
    ])

    Meta.allow_tag_with_these_attributes("mtd", [
      "columnspan",
      "displaystyle",
      "mathvariant",
      "rowspan",
      "scriptlevel"
    ])

    Meta.allow_tag_with_these_attributes("munder", [
      "accentunder",
      "displaystyle",
      "mathvariant",
      "scriptlevel"
    ])

    Meta.allow_tag_with_these_attributes("munderover", [
      "accent",
      "accentunder",
      "displaystyle",
      "mathvariant",
      "scriptlevel"
    ])
  end

  Meta.allow_tag_with_these_attributes(:center, [])
  Meta.allow_tag_with_these_attributes(:small, [])

  Meta.strip_everything_not_covered()
end
