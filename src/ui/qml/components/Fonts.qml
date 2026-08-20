pragma Singleton

import QtQuick 2.12

QtObject {
    id: fonts

    readonly property FontLoader fontAwesomeRegular: FontLoader {
        source: "./Font Awesome 7 Free-Regular-400.otf"
    }
    readonly property FontLoader fontAwesomeSolid: FontLoader {
        source: "./Font Awesome 7 Free-Solid-900.otf"
    }
    readonly property FontLoader fontAwesomeBrands: FontLoader {
        source: "./Font Awesome 7 Brands-Regular-400.otf"
    }

    readonly property string icons: fonts.fontAwesomeRegular.name
    readonly property string solidIcons: fonts.fontAwesomeSolid.name
    readonly property string brands: fonts.fontAwesomeBrands.name
}
