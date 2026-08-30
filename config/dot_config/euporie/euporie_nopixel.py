"""euporie wrapper: SGR-pixel mouse (mode 1016) の問い合わせを抑止する.

herdr 0.8.2 はDECRQMで1016を「有効」と答えるのにcell座標を転送するため、
euporieの全mouse操作が左上に着地する (herdrdev/herdr#3295)。
"""

import sys

from euporie.core.io import Vt100_Output

Vt100_Output.get_sgr_pixel_status = lambda self: None

from euporie.core.__main__ import main  # noqa: E402

sys.exit(main())
