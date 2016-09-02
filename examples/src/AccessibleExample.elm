module Main exposing (..)

import Autocomplete
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.App as Html
import String
import Json.Decode as Json
import Json.Encode as JE


main : Program Never
main =
    Html.program
        { init = init ! []
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.map SetAutoState Autocomplete.subscription


type alias Model =
    { people : List Person
    , autoState : Autocomplete.State
    , howManyToShow : Int
    , query : String
    , selectedPerson : Maybe Person
    , showMenu : Bool
    }


init : Model
init =
    { people = presidents
    , autoState = Autocomplete.empty
    , howManyToShow = 5
    , query = ""
    , selectedPerson = Nothing
    , showMenu = False
    }


type Msg
    = SetQuery String
    | SetAutoState Autocomplete.Msg
    | Wrap Bool
    | Reset
    | HandleEscape
    | SelectPerson String
    | PreviewPerson String
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        newModel =
            case Debug.log "msg" msg of
                SetQuery newQuery ->
                    let
                        showMenu =
                            not << List.isEmpty <| (acceptablePeople newQuery model.people)
                    in
                        { model | query = newQuery, showMenu = showMenu, selectedPerson = Nothing }

                SetAutoState autoMsg ->
                    let
                        ( newState, maybeMsg ) =
                            Autocomplete.update updateConfig autoMsg model.autoState (acceptablePeople model.query model.people) model.howManyToShow

                        newModel =
                            { model | autoState = newState }
                    in
                        case maybeMsg of
                            Nothing ->
                                newModel

                            Just updateMsg ->
                                fst <| update updateMsg newModel

                HandleEscape ->
                    let
                        validOptions =
                            not <| List.isEmpty (acceptablePeople model.query model.people)
                    in
                        case model.selectedPerson of
                            Just person ->
                                if model.query == person.name then
                                    model
                                        |> resetInput
                                else if validOptions then
                                    model
                                        |> removeSelection
                                        |> resetMenu
                                else
                                    { model | query = "" }
                                        |> removeSelection
                                        |> resetMenu

                            Nothing ->
                                if validOptions then
                                    model
                                        |> removeSelection
                                        |> resetMenu
                                else
                                    { model | query = "" }
                                        |> removeSelection
                                        |> resetMenu

                Wrap toTop ->
                    case model.selectedPerson of
                        Just person ->
                            fst <| update Reset model

                        Nothing ->
                            if toTop then
                                { model
                                    | autoState = Autocomplete.resetToLastItem (acceptablePeople model.query model.people) updateConfig model.howManyToShow model.autoState
                                    , selectedPerson = List.head <| List.reverse <| List.take model.howManyToShow <| (acceptablePeople model.query model.people)
                                }
                            else
                                { model
                                    | autoState = Autocomplete.resetToFirstItem (acceptablePeople model.query model.people) updateConfig model.howManyToShow model.autoState
                                    , selectedPerson = List.head <| List.take model.howManyToShow <| (acceptablePeople model.query model.people)
                                }

                Reset ->
                    { model | autoState = Autocomplete.reset updateConfig model.autoState, selectedPerson = Nothing }

                SelectPerson id ->
                    setQuery model id
                        |> resetMenu

                PreviewPerson id ->
                    { model | selectedPerson = Just <| getPersonAtId model.people id }

                NoOp ->
                    model
    in
        newModel ! []


resetInput model =
    { model | query = "" }
        |> removeSelection
        |> resetMenu


removeSelection model =
    { model | selectedPerson = Nothing }


getPersonAtId people id =
    List.filter (\person -> person.name == id) people
        |> List.head
        |> Maybe.withDefault (Person "" 0 "" "")


setQuery model id =
    { model
        | query = .name <| getPersonAtId model.people id
    }


resetMenu model =
    { model
        | autoState = Autocomplete.empty
        , showMenu = False
    }


view : Model -> Html Msg
view model =
    let
        options =
            { preventDefault = True, stopPropagation = False }

        dec =
            (Json.customDecoder keyCode
                (\code ->
                    if code == 38 || code == 40 then
                        Ok NoOp
                    else if code == 27 then
                        Ok HandleEscape
                    else
                        Err "not handling that key"
                )
            )

        menu =
            if model.showMenu then
                [ viewMenu model ]
            else
                []

        query =
            case model.selectedPerson of
                Just person ->
                    person.name

                Nothing ->
                    model.query
    in
        div []
            (List.append
                [ h1 [] [ text "U.S. Presidents" ]
                , input
                    [ onInput SetQuery
                    , onWithOptions "keydown" options dec
                    , value query
                    , property "role" (JE.string "combobox")
                    , property "aria-autocomplete" (JE.string "list")
                    ]
                    []
                ]
                menu
            )


acceptablePeople : String -> List Person -> List Person
acceptablePeople query people =
    let
        lowerQuery =
            String.toLower query
    in
        List.filter (String.contains lowerQuery << String.toLower << .name) people


viewMenu : Model -> Html Msg
viewMenu model =
    div [ class "autocomplete-menu" ]
        [ Html.map SetAutoState (Autocomplete.view viewConfig model.howManyToShow model.autoState (acceptablePeople model.query model.people)) ]


updateConfig : Autocomplete.UpdateConfig Msg Person
updateConfig =
    Autocomplete.updateConfig
        { toId = .name
        , onKeyDown =
            \code maybeId ->
                if code == 38 || code == 40 then
                    Maybe.map PreviewPerson maybeId
                else if code == 13 then
                    Maybe.map SelectPerson maybeId
                else
                    Just <| Reset
        , onTooLow = Just <| Wrap False
        , onTooHigh = Just <| Wrap True
        , onMouseEnter = \_ -> Nothing
        , onMouseLeave = \_ -> Nothing
        , onMouseClick = \id -> Just <| SelectPerson id
        , separateSelections = False
        }


viewConfig : Autocomplete.ViewConfig Person
viewConfig =
    Autocomplete.viewConfig
        { toId = .name
        , ul = [ class "autocomplete-list" ]
        , li = customizedLi
        }


customizedLi :
    Autocomplete.KeySelected
    -> Autocomplete.MouseSelected
    -> Person
    -> Autocomplete.HtmlDetails Never
customizedLi keySelected mouseSelected person =
    if keySelected then
        { attributes = [ class "autocomplete-key-item" ]
        , children = [ Html.text person.name ]
        }
    else if mouseSelected then
        { attributes = [ class "autocomplete-mouse-item" ]
        , children = [ Html.text person.name ]
        }
    else
        { attributes = [ class "autocomplete-item" ]
        , children = [ Html.text person.name ]
        }



-- PEOPLE


type alias Person =
    { name : String
    , year : Int
    , city : String
    , state : String
    }


presidents : List Person
presidents =
    [ Person "George Washington" 1732 "Westmoreland County" "Virginia"
    , Person "John Adams" 1735 "Braintree" "Massachusetts"
    , Person "Thomas Jefferson" 1743 "Shadwell" "Virginia"
    , Person "James Madison" 1751 "Port Conway" "Virginia"
    , Person "James Monroe" 1758 "Monroe Hall" "Virginia"
    , Person "Andrew Jackson" 1767 "Waxhaws Region" "South/North Carolina"
    , Person "John Quincy Adams" 1767 "Braintree" "Massachusetts"
    , Person "William Henry Harrison" 1773 "Charles City County" "Virginia"
    , Person "Martin Van Buren" 1782 "Kinderhook" "New York"
    , Person "Zachary Taylor" 1784 "Barboursville" "Virginia"
    , Person "John Tyler" 1790 "Charles City County" "Virginia"
    , Person "James Buchanan" 1791 "Cove Gap" "Pennsylvania"
    , Person "James K. Polk" 1795 "Pineville" "North Carolina"
    , Person "Millard Fillmore" 1800 "Summerhill" "New York"
    , Person "Franklin Pierce" 1804 "Hillsborough" "New Hampshire"
    , Person "Andrew Johnson" 1808 "Raleigh" "North Carolina"
    , Person "Abraham Lincoln" 1809 "Sinking spring" "Kentucky"
    , Person "Ulysses S. Grant" 1822 "Point Pleasant" "Ohio"
    , Person "Rutherford B. Hayes" 1822 "Delaware" "Ohio"
    , Person "Chester A. Arthur" 1829 "Fairfield" "Vermont"
    , Person "James A. Garfield" 1831 "Moreland Hills" "Ohio"
    , Person "Benjamin Harrison" 1833 "North Bend" "Ohio"
    , Person "Grover Cleveland" 1837 "Caldwell" "New Jersey"
    , Person "William McKinley" 1843 "Niles" "Ohio"
    , Person "Woodrow Wilson" 1856 "Staunton" "Virginia"
    , Person "William Howard Taft" 1857 "Cincinnati" "Ohio"
    , Person "Theodore Roosevelt" 1858 "New York City" "New York"
    , Person "Warren G. Harding" 1865 "Blooming Grove" "Ohio"
    , Person "Calvin Coolidge" 1872 "Plymouth" "Vermont"
    , Person "Herbert Hoover" 1874 "West Branch" "Iowa"
    , Person "Franklin D. Roosevelt" 1882 "Hyde Park" "New York"
    , Person "Harry S. Truman" 1884 "Lamar" "Missouri"
    , Person "Dwight D. Eisenhower" 1890 "Denison" "Texas"
    , Person "Lyndon B. Johnson" 1908 "Stonewall" "Texas"
    , Person "Ronald Reagan" 1911 "Tampico" "Illinois"
    , Person "Richard M. Nixon" 1913 "Yorba Linda" "California"
    , Person "Gerald R. Ford" 1913 "Omaha" "Nebraska"
    , Person "John F. Kennedy" 1917 "Brookline" "Massachusetts"
    , Person "George H. W. Bush" 1924 "Milton" "Massachusetts"
    , Person "Jimmy Carter" 1924 "Plains" "Georgia"
    , Person "George W. Bush" 1946 "New Haven" "Connecticut"
    , Person "Bill Clinton" 1946 "Hope" "Arkansas"
    , Person "Barack Obama" 1961 "Honolulu" "Hawaii"
    ]